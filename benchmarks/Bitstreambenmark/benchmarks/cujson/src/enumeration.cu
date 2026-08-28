#include "hierarchical_common.cuh"

#include <cuda/atomic>

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

constexpr uint32_t THREADS = 256u;
constexpr uint32_t WORDS_PER_THREAD = 1u;
constexpr uint32_t WORDS_PER_CHUNK = THREADS;
static_assert(THREADS % 32u == 0u, "the readiness loop requires full warps");
constexpr uint32_t MAX_EPOCH = 0xffffff00u;
constexpr uint64_t FNV_OFFSET = 1469598103934665603ull;
constexpr uint64_t FNV_PRIME = 1099511628211ull;

#define CUDA_CHECK(call) do { cudaError_t status_ = (call); if (status_ != cudaSuccess) { \
    std::cerr << "CUDA error at " << __FILE__ << ':' << __LINE__ << ": " \
              << cudaGetErrorString(status_) << '\n'; std::exit(EXIT_FAILURE); } } while (0)

struct InputDescriptor {
    uint64_t byte_offset;
    uint64_t byte_size;
    uint32_t word_offset;
};

struct ChunkTask {
    uint32_t input_id;
    uint32_t chunk_id;
};

struct HostInput {
    std::string path;
    uint64_t size = 0u;
    uint32_t word_offset = 0u;
    uint32_t word_count = 0u;
    uint32_t padded_word_count = 0u;
    uint32_t chunk_count = 0u;
};

__device__ __forceinline__ void classifyAndValidateWord(const uint8_t* input,
    uint64_t input_size, uint32_t word_id, uint32_t& slash_word, uint32_t& quote_word,
    uint32_t& operator_word, uint32_t& open_close_word, uint32_t& utf_error) {
    const uint32_t* input_words = reinterpret_cast<const uint32_t*>(input);
    const uint4* input_vectors = reinterpret_cast<const uint4*>(input);
    uint64_t first_input_word_id = static_cast<uint64_t>(word_id) * 8u;
    uint64_t first_vector_id = static_cast<uint64_t>(word_id) * 2u;
    uint4 first_vector = input_vectors[first_vector_id];
    uint4 second_vector = input_vectors[first_vector_id + 1u];
    uint32_t loaded_words[8] = {first_vector.x, first_vector.y, first_vector.z, first_vector.w,
                                second_vector.x, second_vector.y, second_vector.z, second_vector.w};

    utf_error = 0u;
    slash_word = 0u;
    quote_word = 0u;
    operator_word = 0u;
    open_close_word = 0u;
    #pragma unroll
    for (uint32_t part = 0u; part < 8u; ++part) {
        uint64_t input_word_id = first_input_word_id + part;
        uint32_t current = loaded_words[part];
        uint32_t previous = input_word_id == 0u ? 0u :
            (part == 0u ? input_words[input_word_id - 1u] : loaded_words[part - 1u]);
        if (((current | previous) & 0x80808080u) != 0u)
            utf_error |= fullCujsonValidateUtf8FourBytes(current, previous);

        uint32_t slash = __vcmpeq4(current, 0x5c5c5c5cu) & 0x01010101u;
        uint32_t quote = __vcmpeq4(current, 0x22222222u) & 0x01010101u;
        uint32_t open_close = (__vcmpeq4(current, 0x5b5b5b5bu) | __vcmpeq4(current, 0x5d5d5d5du) |
                               __vcmpeq4(current, 0x7b7b7b7bu) | __vcmpeq4(current, 0x7d7d7d7du)) & 0x01010101u;
        uint32_t colon_comma = (__vcmpeq4(current, 0x3a3a3a3au) |
                                __vcmpeq4(current, 0x2c2c2c2cu)) & 0x01010101u;
        slash_word |= fullPackMatches(slash) << (part * 4u);
        quote_word |= fullPackMatches(quote) << (part * 4u);
        open_close_word |= fullPackMatches(open_close) << (part * 4u);
        operator_word |= fullPackMatches(open_close | colon_comma) << (part * 4u);
    }

    uint64_t byte_start = static_cast<uint64_t>(word_id) * 32u;
    uint64_t bytes_left = byte_start < input_size ? input_size - byte_start : 0u;
    if (bytes_left < 32u) {
        uint32_t valid_mask = bytes_left == 0u ? 0u : 0xffffffffu >> (32u - bytes_left);
        slash_word &= valid_mask;
        quote_word &= valid_mask;
        operator_word &= valid_mask;
        open_close_word &= valid_mask;
    }
}

__global__ void perThreadEnumerationKernel(const uint8_t* all_input,
    const InputDescriptor* descriptors, const ChunkTask* tasks,
    uint32_t task_count, uint32_t* next_task,
    volatile uint32_t* slash_bitmap, volatile uint32_t* quote_bitmap,
    volatile uint32_t* operator_bitmap, volatile uint32_t* open_close_bitmap,
    volatile uint32_t* real_quote_bitmap, volatile uint32_t* in_string_bitmap,
    volatile uint32_t* structural_bitmap, uint32_t* classify_ready,
    uint32_t* in_string_ready, uint32_t* utf_errors, uint32_t epoch) {
    __shared__ uint32_t task_position;

    while (true) {
        if (threadIdx.x == 0u) task_position = atomicAdd(next_task, 1u);
        __syncthreads();
        if (task_position >= task_count) return;

        ChunkTask task = tasks[task_position];
        InputDescriptor descriptor = descriptors[task.input_id];
        const uint8_t* input = all_input + descriptor.byte_offset;
        uint32_t word_id = task.chunk_id * WORDS_PER_CHUNK + threadIdx.x;
        uint32_t output_id = descriptor.word_offset + word_id;

        // Stage 1: write the original cuJSON classification bitmaps to GM.
        uint32_t slash_word = 0u, quote_word = 0u, operator_word = 0u;
        uint32_t open_close_word = 0u, thread_utf_error = 0u;
        classifyAndValidateWord(input, descriptor.byte_size, word_id, slash_word,
            quote_word, operator_word, open_close_word, thread_utf_error);
        slash_bitmap[output_id] = slash_word;
        quote_bitmap[output_id] = quote_word;
        operator_bitmap[output_id] = operator_word;
        open_close_bitmap[output_id] = open_close_word;
        if (thread_utf_error != 0u) atomicOr(utf_errors + task.input_id, thread_utf_error);
        cuda::atomic_ref<uint32_t, cuda::thread_scope_device>
            my_classify_ready(classify_ready[output_id]);
        my_classify_ready.store(epoch, cuda::memory_order_release);

        // Stage 2: reload the cuJSON slash/quote bitmaps and enumerate both
        // possible real-quote results before resolving the incoming slash state.
        slash_word = slash_bitmap[output_id];
        quote_word = quote_bitmap[output_id];
        uint32_t possible_escaped = quote_word & ((slash_word << 1u) | 1u);
        uint32_t real_quote_if_slash_zero = possible_escaped == 0u ? quote_word : fullFilterEscapedQuotesWord(quote_word, slash_word, 0u);
        uint32_t real_quote_if_slash_one = possible_escaped == 0u ? quote_word : fullFilterEscapedQuotesWord(quote_word, slash_word, 1u);

        // Validation reads the actual predecessor slash bitmap from GM. The
        // result only selects one of the two candidates; it does not recompute.
        uint32_t incoming_slash = 0u;
        if (possible_escaped != 0u) {
            int64_t previous_word = static_cast<int64_t>(word_id) - 1;
            while (previous_word >= 0) {
                uint32_t previous_output = descriptor.word_offset +
                    static_cast<uint32_t>(previous_word);
                cuda::atomic_ref<uint32_t, cuda::thread_scope_device>
                    previous_ready(classify_ready[previous_output]);
                while (previous_ready.load(cuda::memory_order_acquire) != epoch)
                    __nanosleep(64u);
                uint32_t previous_slashes = slash_bitmap[previous_output];
                uint32_t trailing_slashes = static_cast<uint32_t>(
                    __clz(~previous_slashes));
                if (trailing_slashes != 32u) {
                    incoming_slash = trailing_slashes & 1u;
                    break;
                }
                --previous_word;
            }
        }
        uint32_t real_quote = incoming_slash == 0u ? real_quote_if_slash_zero : real_quote_if_slash_one;
        real_quote_bitmap[output_id] = real_quote;

        // Stage 3: reload the selected real-quote bitmap from GM and enumerate
        // both incoming in-string states before waiting for the predecessor.
        real_quote = real_quote_bitmap[output_id];
        uint32_t in_string_if_zero = fullPrefixXorWord(real_quote);
        uint32_t in_string_if_one = ~in_string_if_zero;
        uint32_t incoming_string = 0u;
        bool in_string_published = false;
        while (true) {
            bool predecessor_ready = word_id == 0u;
            if (!in_string_published && !predecessor_ready) {
                cuda::atomic_ref<uint32_t, cuda::thread_scope_device>
                    previous_ready(in_string_ready[output_id - 1u]);
                if (previous_ready.load(cuda::memory_order_acquire) == epoch) {
                    incoming_string = in_string_bitmap[output_id - 1u] >> 31u;
                    predecessor_ready = true;
                }
            }
            if (!in_string_published && predecessor_ready) {
                // Validation is only selection: both candidate bitmaps were
                // computed before the acquire-poll completed.
                uint32_t in_string = incoming_string == 0u ? in_string_if_zero : in_string_if_one;
                in_string_bitmap[output_id] = in_string;
                cuda::atomic_ref<uint32_t, cuda::thread_scope_device>
                    my_ready(in_string_ready[output_id]);
                my_ready.store(epoch, cuda::memory_order_release);
                in_string_published = true;
            }
            if (__all_sync(0xffffffffu, in_string_published)) break;
            __nanosleep(64u);
        }

        // Stage 4: reload the same GM payloads as cuJSON's final filter.
        uint32_t in_string = in_string_bitmap[output_id];
        operator_word = operator_bitmap[output_id];
        open_close_word = open_close_bitmap[output_id];
        structural_bitmap[output_id] = ~in_string & operator_word;
        open_close_bitmap[output_id] = ~in_string & open_close_word;
        __syncthreads();
    }
}

static bool validUtf8(const uint8_t* data, uint64_t size) {
    uint64_t position = 0u;
    while (position < size) {
        uint8_t first = data[position++];
        if (first < 0x80u) continue;
        uint32_t continuation_count = 0u;
        uint8_t second_min = 0x80u, second_max = 0xbfu;
        if (first >= 0xc2u && first <= 0xdfu) continuation_count = 1u;
        else if (first >= 0xe0u && first <= 0xefu) {
            continuation_count = 2u;
            if (first == 0xe0u) second_min = 0xa0u;
            if (first == 0xedu) second_max = 0x9fu;
        } else if (first >= 0xf0u && first <= 0xf4u) {
            continuation_count = 3u;
            if (first == 0xf0u) second_min = 0x90u;
            if (first == 0xf4u) second_max = 0x8fu;
        } else return false;
        if (position + continuation_count > size) return false;
        if (data[position] < second_min || data[position] > second_max) return false;
        ++position;
        for (uint32_t continuation = 1u; continuation < continuation_count; ++continuation, ++position)
            if (data[position] < 0x80u || data[position] > 0xbfu) return false;
    }
    return true;
}

static void makeCpuReference(const uint8_t* data, uint64_t size, uint32_t word_count,
    std::vector<uint32_t>& structural, std::vector<uint32_t>& open_close) {
    structural.assign(word_count, 0u);
    open_close.assign(word_count, 0u);
    bool in_string = false;
    uint32_t slash_run = 0u;
    for (uint64_t position = 0u; position < size; ++position) {
        uint8_t byte = data[position];
        bool real_quote = byte == static_cast<uint8_t>('"') && (slash_run & 1u) == 0u;
        if (real_quote) in_string = !in_string;
        bool is_open_close = byte == '[' || byte == ']' || byte == '{' || byte == '}';
        bool is_operator = is_open_close || byte == ':' || byte == ',';
        uint32_t bit = 1u << (position & 31u);
        uint32_t word = static_cast<uint32_t>(position >> 5u);
        if (!in_string && is_operator) structural[word] |= bit;
        if (!in_string && is_open_close) open_close[word] |= bit;
        slash_run = byte == static_cast<uint8_t>('\\') ? slash_run + 1u : 0u;
    }
}

static uint64_t hashWords(const uint32_t* words, uint32_t count) {
    uint64_t hash = FNV_OFFSET;
    for (uint32_t word = 0u; word < count; ++word) {
        hash ^= words[word];
        hash *= FNV_PRIME;
    }
    return hash;
}

static uint64_t appendHash(uint64_t hash, uint64_t value) {
    hash ^= value;
    return hash * FNV_PRIME;
}

static bool parsePositiveInt(const char* text, int& value) {
    char* end = nullptr;
    long parsed = std::strtol(text, &end, 10);
    if (end == text || *end != '\0' || parsed <= 0 || parsed > std::numeric_limits<int>::max()) return false;
    value = static_cast<int>(parsed);
    return true;
}

static cudaError_t launchEnumeration(uint32_t resident_blocks,
    const uint8_t* input, const InputDescriptor* descriptors,
    const ChunkTask* tasks, uint32_t task_count, uint32_t* next_task,
    uint32_t* slash_bitmap, uint32_t* quote_bitmap, uint32_t* operator_bitmap,
    uint32_t* open_close_bitmap, uint32_t* real_quote_bitmap,
    uint32_t* in_string_bitmap, uint32_t* structural_bitmap,
    uint32_t* classify_ready, uint32_t* in_string_ready,
    uint32_t* utf_errors, uint32_t epoch) {
    cudaError_t status = cudaMemsetAsync(next_task, 0, sizeof(uint32_t));
    if (status != cudaSuccess) return status;
    void* arguments[] = {&input, &descriptors, &tasks, &task_count, &next_task,
        &slash_bitmap, &quote_bitmap, &operator_bitmap, &open_close_bitmap,
        &real_quote_bitmap, &in_string_bitmap, &structural_bitmap,
        &classify_ready, &in_string_ready, &utf_errors, &epoch};
    return cudaLaunchCooperativeKernel(
        reinterpret_cast<const void*>(perThreadEnumerationKernel),
        dim3(resident_blocks), dim3(THREADS), arguments, 0u, nullptr);
}

int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "usage: " << argv[0] << " RUNS file1.json [file2.json ...]\n";
        return EXIT_FAILURE;
    }
    int runs = 0;
    if (!parsePositiveInt(argv[1], runs)) {
        std::cerr << "RUNS must be a positive integer\n";
        return EXIT_FAILURE;
    }
    if (static_cast<uint32_t>(runs) > MAX_EPOCH - 100u) {
        std::cerr << "RUNS exceeds the epoch range\n";
        return EXIT_FAILURE;
    }

    std::vector<HostInput> inputs(static_cast<size_t>(argc - 2));
    uint64_t total_words_64 = 0u;
    uint64_t total_chunks_64 = 0u;
    uint32_t maximum_chunks = 0u;
    for (int argument = 2; argument < argc; ++argument) {
        HostInput& input = inputs[static_cast<size_t>(argument - 2)];
        input.path = argv[argument];
        std::ifstream file(input.path, std::ios::binary | std::ios::ate);
        if (!file) {
            std::cerr << "cannot open " << input.path << '\n';
            return EXIT_FAILURE;
        }
        std::streamoff end = file.tellg();
        if (end < 0) return EXIT_FAILURE;
        input.size = static_cast<uint64_t>(end);
        uint64_t words = (input.size + 31u) / 32u;
        uint64_t padded_words = ((words + 1u + WORDS_PER_CHUNK - 1u) /
                                 WORDS_PER_CHUNK) * WORDS_PER_CHUNK;
        uint64_t chunks = padded_words / WORDS_PER_CHUNK;
        if (words > std::numeric_limits<uint32_t>::max() ||
            padded_words > std::numeric_limits<uint32_t>::max() ||
            chunks > std::numeric_limits<uint32_t>::max() ||
            total_words_64 + padded_words > std::numeric_limits<uint32_t>::max() ||
            total_chunks_64 + chunks > std::numeric_limits<uint32_t>::max()) {
            std::cerr << "combined inputs exceed the 32-bit index range\n";
            return EXIT_FAILURE;
        }
        input.word_offset = static_cast<uint32_t>(total_words_64);
        input.word_count = static_cast<uint32_t>(words);
        input.padded_word_count = static_cast<uint32_t>(padded_words);
        input.chunk_count = static_cast<uint32_t>(chunks);
        maximum_chunks = std::max(maximum_chunks, input.chunk_count);
        total_words_64 += padded_words;
        total_chunks_64 += chunks;
    }

    uint32_t total_words = static_cast<uint32_t>(total_words_64);
    uint32_t total_chunks = static_cast<uint32_t>(total_chunks_64);
    size_t input_storage_bytes = static_cast<size_t>(total_words) * 32u;
    std::vector<uint8_t> all_input(input_storage_bytes, 0u);
    std::vector<InputDescriptor> descriptors(inputs.size());
    for (size_t index = 0u; index < inputs.size(); ++index) {
        HostInput& input = inputs[index];
        uint64_t byte_offset = static_cast<uint64_t>(input.word_offset) * 32u;
        std::ifstream file(input.path, std::ios::binary);
        file.read(reinterpret_cast<char*>(all_input.data() + byte_offset),
                  static_cast<std::streamsize>(input.size));
        if (!file && input.size != 0u) {
            std::cerr << "failed to read " << input.path << '\n';
            return EXIT_FAILURE;
        }
        descriptors[index] = {byte_offset, input.size, input.word_offset};
    }

    // Round-robin tasks expose all input pipelines while preserving the rule
    // that every chunk is assigned only after its predecessor was assigned.
    std::vector<ChunkTask> tasks;
    tasks.reserve(total_chunks);
    for (uint32_t chunk = 0u; chunk < maximum_chunks; ++chunk)
        for (uint32_t input_id = 0u; input_id < inputs.size(); ++input_id)
            if (chunk < inputs[input_id].chunk_count) tasks.push_back({input_id, chunk});

    uint8_t* device_input = nullptr;
    InputDescriptor* device_descriptors = nullptr;
    ChunkTask* device_tasks = nullptr;
    uint32_t* device_next_task = nullptr;
    uint32_t* device_slash = nullptr;
    uint32_t* device_quote = nullptr;
    uint32_t* device_operator = nullptr;
    uint32_t* device_open_close = nullptr;
    uint32_t* device_real_quote = nullptr;
    uint32_t* device_in_string = nullptr;
    uint32_t* device_structural = nullptr;
    uint32_t* device_classify_ready = nullptr;
    uint32_t* device_in_string_ready = nullptr;
    uint32_t* device_utf_errors = nullptr;
    CUDA_CHECK(cudaMalloc(&device_input, input_storage_bytes));
    CUDA_CHECK(cudaMalloc(&device_descriptors, descriptors.size() * sizeof(InputDescriptor)));
    CUDA_CHECK(cudaMalloc(&device_tasks, tasks.size() * sizeof(ChunkTask)));
    CUDA_CHECK(cudaMalloc(&device_next_task, sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_slash, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_quote, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_operator, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_open_close, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_real_quote, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_in_string, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_structural, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_classify_ready, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_in_string_ready, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_utf_errors, inputs.size() * sizeof(uint32_t)));
    CUDA_CHECK(cudaMemcpy(device_input, all_input.data(), input_storage_bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(device_descriptors, descriptors.data(),
                          descriptors.size() * sizeof(InputDescriptor), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(device_tasks, tasks.data(), tasks.size() * sizeof(ChunkTask),
                          cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(device_classify_ready, 0, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMemset(device_in_string_ready, 0, total_words * sizeof(uint32_t)));
    CUDA_CHECK(cudaMemset(device_utf_errors, 0, inputs.size() * sizeof(uint32_t)));

    int cooperative_launch = 0;
    int multiprocessors = 0;
    int blocks_per_multiprocessor = 0;
    CUDA_CHECK(cudaDeviceGetAttribute(&cooperative_launch, cudaDevAttrCooperativeLaunch, 0));
    CUDA_CHECK(cudaDeviceGetAttribute(&multiprocessors, cudaDevAttrMultiProcessorCount, 0));
    if (cooperative_launch == 0) {
        std::cerr << "device does not support cooperative launch\n";
        return EXIT_FAILURE;
    }
    CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(&blocks_per_multiprocessor,
        perThreadEnumerationKernel, THREADS, 0u));
    uint32_t resident_capacity = static_cast<uint32_t>(multiprocessors * blocks_per_multiprocessor);
    uint32_t resident_blocks = std::min(total_chunks, resident_capacity);
    if (resident_blocks == 0u) {
        std::cerr << "enumeration kernel has zero resident capacity\n";
        return EXIT_FAILURE;
    }

    for (uint32_t warmup = 0u; warmup < 3u; ++warmup)
        CUDA_CHECK(launchEnumeration(resident_blocks, device_input, device_descriptors, device_tasks,
            total_chunks, device_next_task, device_slash, device_quote, device_operator,
            device_open_close, device_real_quote, device_in_string, device_structural,
            device_classify_ready, device_in_string_ready, device_utf_errors, warmup + 1u));
    CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t start = nullptr, stop = nullptr;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    double total_ms = 0.0;
    for (int run = 0; run < runs; ++run) {
        CUDA_CHECK(cudaEventRecord(start));
        CUDA_CHECK(launchEnumeration(resident_blocks, device_input, device_descriptors, device_tasks,
            total_chunks, device_next_task, device_slash, device_quote, device_operator,
            device_open_close, device_real_quote, device_in_string, device_structural,
            device_classify_ready, device_in_string_ready, device_utf_errors, static_cast<uint32_t>(run + 100u)));
        CUDA_CHECK(cudaEventRecord(stop));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float elapsed_ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        total_ms += elapsed_ms;
    }

    std::vector<uint32_t> structural(total_words), open_close(total_words), utf_errors(inputs.size());
    CUDA_CHECK(cudaMemcpy(structural.data(), device_structural,
                          total_words * sizeof(uint32_t), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(open_close.data(), device_open_close,
                          total_words * sizeof(uint32_t), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(utf_errors.data(), device_utf_errors,
                          inputs.size() * sizeof(uint32_t), cudaMemcpyDeviceToHost));

    bool all_correct = true;
    uint64_t combined_checksum = FNV_OFFSET;
    std::vector<uint64_t> structural_hashes(inputs.size()), open_close_hashes(inputs.size());
    for (size_t index = 0u; index < inputs.size(); ++index) {
        const HostInput& input = inputs[index];
        const uint8_t* input_bytes = all_input.data() + static_cast<size_t>(input.word_offset) * 32u;
        std::vector<uint32_t> expected_structural, expected_open_close;
        makeCpuReference(input_bytes, input.size, input.word_count,
                         expected_structural, expected_open_close);
        bool correct = (utf_errors[index] != 0u) == !validUtf8(input_bytes, input.size);
        for (uint32_t word = 0u; word < input.word_count; ++word) {
            uint32_t output_word = input.word_offset + word;
            correct = correct && structural[output_word] == expected_structural[word] &&
                      open_close[output_word] == expected_open_close[word];
        }
        all_correct = all_correct && correct;
        structural_hashes[index] = hashWords(structural.data() + input.word_offset, input.word_count);
        open_close_hashes[index] = hashWords(open_close.data() + input.word_offset, input.word_count);
        combined_checksum = appendHash(combined_checksum, structural_hashes[index]);
        combined_checksum = appendHash(combined_checksum, open_close_hashes[index]);
        combined_checksum = appendHash(combined_checksum, utf_errors[index] != 0u ? 1u : 0u);
    }

    std::cout << std::fixed << std::setprecision(3)
              << "method=cujson_enumeration inputs=" << inputs.size()
              << " threads=" << THREADS << " words_per_thread=" << WORDS_PER_THREAD
              << " logical_blocks=" << total_chunks << " resident_blocks=" << resident_blocks
              << " avg_us=" << total_ms * 1000.0 / runs
              << " outputs_correct=" << (all_correct ? "PASS" : "FAIL")
              << " checksum=" << combined_checksum << '\n';
    for (size_t index = 0u; index < inputs.size(); ++index)
        std::cout << "input=" << index << " bytes=" << inputs[index].size
                  << " words=" << inputs[index].word_count
                  << " chunks=" << inputs[index].chunk_count
                  << " structural_hash=" << structural_hashes[index]
                  << " open_close_hash=" << open_close_hashes[index]
                  << " utf_error=" << (utf_errors[index] != 0u) << '\n';

    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaFree(device_input));
    CUDA_CHECK(cudaFree(device_descriptors));
    CUDA_CHECK(cudaFree(device_tasks));
    CUDA_CHECK(cudaFree(device_next_task));
    CUDA_CHECK(cudaFree(device_slash));
    CUDA_CHECK(cudaFree(device_quote));
    CUDA_CHECK(cudaFree(device_operator));
    CUDA_CHECK(cudaFree(device_open_close));
    CUDA_CHECK(cudaFree(device_real_quote));
    CUDA_CHECK(cudaFree(device_in_string));
    CUDA_CHECK(cudaFree(device_structural));
    CUDA_CHECK(cudaFree(device_classify_ready));
    CUDA_CHECK(cudaFree(device_in_string_ready));
    CUDA_CHECK(cudaFree(device_utf_errors));
    return all_correct ? EXIT_SUCCESS : EXIT_FAILURE;
}

#undef CUDA_CHECK
