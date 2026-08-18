#include "Bitstream/BitstreamOps.h"
#include "Bitstream/BitstreamPasses.h"

#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/GPU/IR/GPUDialect.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/Matchers.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/SymbolTable.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/Support/FormatVariadic.h"

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <functional>
#include <memory>
#include <optional>
#include <string>

namespace bitstream {
#define GEN_PASS_DEF_BITSTREAMRECOVERSEMANTICS
#include "Bitstream/BitstreamPasses.h.inc"
} // namespace bitstream

using namespace mlir;
using namespace bitstream;

namespace {

struct Fact {
  std::string role;
  llvm::StringMap<std::string> attrs;
};

struct FunctionFacts {
  std::string name;
  std::string kind;
  std::string sourceFunction;
  SmallVector<Fact> facts;
};

struct AccessAction {
  llvm::StringMap<std::string> attrs;
  // This is a recovery-time fact only.  It is derived from an enclosing
  // scf.while whose carried index walks backwards, and is never printed as an
  // attribute on a read/write.  Materialization reconstructs the conservative
  // access set as an scf.while with a loop-carried SSA index.
  bool hasUnboundedIteration = false;
};

struct AccessStage {
  std::string name;
  std::string kind;
  std::string recoveryRule;
  SmallVector<AccessAction> actions;
};

static StringRef getStringAttr(Operation *op, StringRef name,
                               StringRef fallback = "") {
  if (auto attr = op->getAttrOfType<StringAttr>(name))
    return attr.getValue();
  return fallback;
}

static std::string getAttr(const Fact &fact, StringRef name,
                           StringRef fallback = "") {
  auto it = fact.attrs.find(name);
  if (it == fact.attrs.end())
    return fallback.str();
  return it->second;
}

static std::string getAttr(const AccessAction &action, StringRef name,
                           StringRef fallback = "") {
  auto it = action.attrs.find(name);
  if (it == action.attrs.end())
    return fallback.str();
  return it->second;
}

static SmallVector<std::string> splitCSV(StringRef text) {
  SmallVector<std::string> result;
  SmallVector<StringRef> parts;
  text.split(parts, ",");
  for (StringRef part : parts) {
    part = part.trim();
    if (!part.empty())
      result.push_back(part.str());
  }
  return result;
}

static bool containsCSVToken(StringRef text, StringRef token) {
  for (const std::string &part : splitCSV(text))
    if (part == token)
      return true;
  return false;
}

static std::optional<int64_t> parseInteger(StringRef text) {
  int64_t value = 0;
  if (text.getAsInteger(10, value))
    return std::nullopt;
  return value;
}

static std::string sanitize(StringRef name) {
  std::string result = name.str();
  for (char &ch : result)
    if (!std::isalnum(static_cast<unsigned char>(ch)) && ch != '_')
      ch = '_';
  return result;
}

static SmallVector<Fact> getFactsByRole(const FunctionFacts &fn,
                                        StringRef role) {
  SmallVector<Fact> result;
  for (const Fact &fact : fn.facts)
    if (fact.role == role)
      result.push_back(fact);
  return result;
}

static const Fact *findFactByRole(const FunctionFacts &fn, StringRef role) {
  for (const Fact &fact : fn.facts)
    if (fact.role == role)
      return &fact;
  return nullptr;
}

static SmallVector<std::string> getParamNames(const FunctionFacts &fn) {
  SmallVector<std::string> result;
  for (const Fact &fact : fn.facts)
    if (fact.role == "param")
      result.push_back(getAttr(fact, "name"));
  return result;
}

static llvm::StringMap<std::string>
buildParamActualMap(const FunctionFacts &stage) {
  llvm::StringMap<std::string> result;
  const Fact *entry = findFactByRole(stage, "entry_call");
  if (!entry)
    return result;
  SmallVector<std::string> actuals = splitCSV(getAttr(*entry, "args"));
  SmallVector<std::string> params = getParamNames(stage);
  for (size_t i = 0, e = std::min(params.size(), actuals.size()); i < e; ++i)
    result[params[i]] = actuals[i];
  return result;
}

static std::string mapBuffer(StringRef formal,
                             const llvm::StringMap<std::string> &mapping) {
  auto it = mapping.find(formal);
  if (it == mapping.end())
    return sanitize(formal);
  return sanitize(it->second);
}

static AccessAction
action(std::initializer_list<std::pair<StringRef, std::string>> attrs) {
  AccessAction result;
  for (auto [key, value] : attrs)
    result.attrs[key] = value;
  return result;
}

static void copyPrefixedAttrs(const Fact &fact, AccessAction &record,
                              StringRef prefix,
                              StringRef targetPrefix = StringRef()) {
  std::string source = prefix.str();
  std::string sourceWithUnderscore = source + "_";
  std::string target = targetPrefix.empty() ? source : targetPrefix.str();
  for (const auto &entry : fact.attrs) {
    StringRef key = entry.getKey();
    if (key == source) {
      record.attrs[target] = entry.getValue();
      continue;
    }
    if (!key.starts_with(sourceWithUnderscore))
      continue;
    std::string rewritten = target;
    rewritten += key.drop_front(source.size()).str();
    record.attrs[rewritten] = entry.getValue();
  }
}

static void copySourceAttrs(const Fact &fact, AccessAction &record) {
  if (!getAttr(fact, "source_line").empty())
    record.attrs["source_line"] = getAttr(fact, "source_line");
  if (!getAttr(fact, "source_file").empty())
    record.attrs["source_file"] = getAttr(fact, "source_file");
}

static llvm::StringMap<std::string>
buildParamTypeMap(const FunctionFacts &stage) {
  llvm::StringMap<std::string> result;
  for (const Fact &fact : stage.facts)
    if (fact.role == "param")
      result[getAttr(fact, "name")] = getAttr(fact, "type");
  return result;
}

static std::string bytesForType(StringRef type) {
  if (type.contains("uint8_t") || type.contains("char") ||
      type.contains("bool"))
    return "1";
  if (type.contains("uint16_t"))
    return "2";
  if (type.contains("uint64_t") || type.contains("size_t") ||
      type.contains("long"))
    return "8";
  return "4";
}

static std::string
bytesForFormalBuffer(StringRef formal,
                     const llvm::StringMap<std::string> &paramTypes) {
  auto it = paramTypes.find(formal);
  if (it == paramTypes.end())
    return "4";
  return bytesForType(it->second);
}

static bool hasSourceLocation(const Fact &fact) {
  return !getAttr(fact, "source_line").empty() ||
         !getAttr(fact, "source_text").empty();
}

static bool shouldMaterializeIndexDef(const FunctionFacts &stage,
                                      const Fact &decl) {
  std::string nameStorage = getAttr(decl, "name");
  StringRef name(nameStorage);
  if (name.empty())
    return false;
  for (const Fact &fact : stage.facts) {
    if (getAttr(fact, "index") == name)
      return true;
    for (const auto &entry : fact.attrs)
      if (entry.getKey().ends_with("_symbol") && entry.getValue() == name)
        return true;
  }
  return false;
}

static std::string compact(StringRef text) {
  std::string result;
  for (char ch : text)
    if (!std::isspace(static_cast<unsigned char>(ch)))
      result.push_back(ch);
  return result;
}

static bool addUniqueRead(AccessStage &stage, llvm::StringSet<> &seenReads,
                          StringRef buffer, StringRef index, StringRef bytes,
                          StringRef meaning) {
  if (buffer.empty() || index.empty())
    return false;
  std::string key = buffer.str() + "|" + index.str();
  if (seenReads.contains(key))
    return false;
  seenReads.insert(key);
  stage.actions.push_back(action({{"kind", "read"},
                                  {"buffer", buffer.str()},
                                  {"index", index.str()},
                                  {"bytes", bytes.str()},
                                  {"meaning", meaning.str()}}));
  return true;
}

static bool addUniqueStateProjection(AccessStage &stage,
                                     llvm::StringSet<> &seenProjections,
                                     StringRef buffer, StringRef index,
                                     int64_t domain,
                                     const AccessAction &extraAttrs) {
  if (buffer.empty() || index.empty())
    return false;
  std::string key =
      buffer.str() + "|" + index.str() + "|" + std::to_string(domain);
  if (seenProjections.contains(key))
    return false;
  seenProjections.insert(key);

  AccessAction record = action({{"kind", "state_projection"},
                                {"buffer", buffer.str()},
                                {"index", index.str()},
                                {"domain", std::to_string(domain)},
                                {"modulus", std::to_string(domain)}});
  for (const auto &entry : extraAttrs.attrs)
    record.attrs[entry.getKey()] = entry.getValue();
  stage.actions.push_back(std::move(record));
  return true;
}

static bool hasLowBitProjection(const Fact &expr) {
  if (getAttr(expr, "has_low_bit") == "true")
    return true;
  std::string text = getAttr(expr, "expr");
  return text.find("& 1") != std::string::npos ||
         text.find("&1") != std::string::npos;
}

static bool factUsesValue(const Fact &fact, StringRef value);

static bool isPopcountCallee(StringRef callee) {
  return callee == "__popc" || callee == "__builtin_popcount" ||
         callee == "__builtin_popcountll" || callee == "popcount" ||
         callee == "popcount32" || callee == "popcount64";
}

static bool hasPopcountCall(const Fact &fact) {
  for (const std::string &callee : splitCSV(getAttr(fact, "calls")))
    if (isPopcountCallee(callee))
      return true;
  if (isPopcountCallee(getAttr(fact, "callee")))
    return true;
  std::string value = getAttr(fact, "value");
  return value.find("__popc(") != std::string::npos ||
         value.find("popcount(") != std::string::npos;
}

static bool isPopcountUseOfValue(const Fact &fact, StringRef value) {
  if (!hasPopcountCall(fact))
    return false;
  return factUsesValue(fact, value);
}

static bool isValueConsumedAfterDefinition(const FunctionFacts &stage,
                                           StringRef value) {
  for (const Fact &expr : getFactsByRole(stage, "expr_def")) {
    if (getAttr(expr, "target") == value)
      continue;
    if (containsCSVToken(getAttr(expr, "uses"), value))
      return true;
  }
  for (const Fact &call : getFactsByRole(stage, "call"))
    if (containsCSVToken(getAttr(call, "args"), value))
      return true;
  for (const Fact &store : getFactsByRole(stage, "array_store")) {
    if (getAttr(store, "value") == value ||
        containsCSVToken(getAttr(store, "uses"), value))
      return true;
  }
  return false;
}

static std::optional<int64_t> parseInteger(StringRef text);

static bool factUsesValue(const Fact &fact, StringRef value) {
  return containsCSVToken(getAttr(fact, "uses"), value) ||
         containsCSVToken(getAttr(fact, "args"), value) ||
         getAttr(fact, "value") == value || getAttr(fact, "rhs") == value ||
         getAttr(fact, "lhs") == value;
}

static bool scalarProjectionHasNoExactReadEscapes(const FunctionFacts &stage,
                                                  StringRef loadedVar,
                                                  StringRef summaryVar,
                                                  StringRef stateVar) {
  for (const Fact &expr : getFactsByRole(stage, "expr_def")) {
    std::string target = getAttr(expr, "target");
    if (target == summaryVar &&
        containsCSVToken(getAttr(expr, "uses"), loadedVar))
      continue;
    if (target == stateVar &&
        containsCSVToken(getAttr(expr, "uses"), summaryVar) &&
        hasLowBitProjection(expr))
      continue;
    if (factUsesValue(expr, loadedVar) || factUsesValue(expr, summaryVar))
      return false;
  }

  for (const Fact &call : getFactsByRole(stage, "call")) {
    if (factUsesValue(call, loadedVar) || factUsesValue(call, summaryVar))
      return false;
  }

  for (const Fact &store : getFactsByRole(stage, "array_store")) {
    if (factUsesValue(store, loadedVar) || factUsesValue(store, summaryVar))
      return false;
  }

  return true;
}

static bool popcountProjectionHasNoExactReadEscapes(const FunctionFacts &stage,
                                                    StringRef loadedVar) {
  for (const Fact &expr : getFactsByRole(stage, "expr_def")) {
    if (!factUsesValue(expr, loadedVar))
      continue;
    if (isPopcountUseOfValue(expr, loadedVar))
      continue;
    return false;
  }

  for (const Fact &call : getFactsByRole(stage, "call")) {
    if (!factUsesValue(call, loadedVar))
      continue;
    if (isPopcountUseOfValue(call, loadedVar))
      continue;
    return false;
  }

  for (const Fact &store : getFactsByRole(stage, "array_store")) {
    if (!factUsesValue(store, loadedVar))
      continue;
    if (isPopcountUseOfValue(store, loadedVar))
      continue;
    return false;
  }

  return true;
}

static int64_t bitsNeededForDomain(int64_t domain) {
  if (domain <= 1)
    return 1;
  int64_t bits = 0;
  int64_t values = domain - 1;
  while (values > 0) {
    ++bits;
    values >>= 1;
  }
  return bits;
}

static bool arrayRefMatches(const Fact &fact, StringRef prefix,
                            StringRef buffer, StringRef index) {
  std::string bufferKey = prefix.str() + "_buffer";
  std::string indexKey = prefix.str() + "_index";
  return getAttr(fact, bufferKey) == buffer && getAttr(fact, indexKey) == index;
}

static bool hasLowBitArrayRef(const Fact &fact, StringRef buffer,
                              StringRef index) {
  int64_t count =
      parseInteger(getAttr(fact, "low_bit_array_ref_count")).value_or(0);
  for (int64_t i = 0; i < count; ++i) {
    std::string prefix = "low_bit_array" + std::to_string(i);
    if (arrayRefMatches(fact, prefix, buffer, index))
      return true;
  }
  return false;
}

static bool arrayRefUseIsOnlyLowBit(const Fact &fact, StringRef buffer,
                                    StringRef index) {
  int64_t count = parseInteger(getAttr(fact, "array_ref_count")).value_or(0);
  bool found = false;
  for (int64_t i = 0; i < count; ++i) {
    std::string prefix = "array" + std::to_string(i);
    if (!arrayRefMatches(fact, prefix, buffer, index))
      continue;
    found = true;
    if (!hasLowBitArrayRef(fact, buffer, index))
      return false;
  }
  return found;
}

static bool arrayProjectionHasNoExactReadEscapes(const FunctionFacts &stage,
                                                 StringRef buffer,
                                                 StringRef index) {
  for (const Fact &load : getFactsByRole(stage, "array_load_var"))
    if (getAttr(load, "buffer") == buffer && getAttr(load, "index") == index)
      return false;

  for (const Fact &expr : getFactsByRole(stage, "expr_def")) {
    int64_t count = parseInteger(getAttr(expr, "array_ref_count")).value_or(0);
    for (int64_t i = 0; i < count; ++i) {
      std::string prefix = "array" + std::to_string(i);
      if (!arrayRefMatches(expr, prefix, buffer, index))
        continue;
      if (!arrayRefUseIsOnlyLowBit(expr, buffer, index))
        return false;
    }
  }

  return true;
}

static void
addScalarLowBitStateProjections(const FunctionFacts &stage, AccessStage &result,
                                const llvm::StringMap<std::string> &paramActual,
                                const llvm::StringMap<std::string> &paramTypes,
                                llvm::StringSet<> &seenReads,
                                llvm::StringSet<> &seenProjections) {
  SmallVector<Fact> exprs = getFactsByRole(stage, "expr_def");

  for (const Fact &load : getFactsByRole(stage, "array_load_var")) {
    std::string loadedVar = getAttr(load, "target");
    std::string formal = getAttr(load, "buffer");
    std::string index = getAttr(load, "index");
    if (loadedVar.empty() || formal.empty() || index.empty())
      continue;

    for (const Fact &summaryExpr : exprs) {
      std::string summaryVar = getAttr(summaryExpr, "target");
      if (summaryVar.empty() || summaryVar == loadedVar)
        continue;
      if (!containsCSVToken(getAttr(summaryExpr, "uses"), loadedVar))
        continue;

      for (const Fact &stateExpr : exprs) {
        std::string stateVar = getAttr(stateExpr, "target");
        if (stateVar.empty() || stateVar == summaryVar)
          continue;
        if (!hasLowBitProjection(stateExpr))
          continue;
        if (!containsCSVToken(getAttr(stateExpr, "uses"), summaryVar))
          continue;
        if (!isValueConsumedAfterDefinition(stage, stateVar))
          continue;

        std::string buffer = mapBuffer(formal, paramActual);
        AccessAction indexAttrs;
        copyPrefixedAttrs(load, indexAttrs, "index");
        bool noExactReadEscapes = scalarProjectionHasNoExactReadEscapes(
            stage, loadedVar, summaryVar, stateVar);
        std::string readKey = buffer + "|" + index;
        if (!seenReads.contains(readKey)) {
          seenReads.insert(readKey);
          AccessAction readRecord =
              action({{"kind", "read"},
                      {"buffer", buffer},
                      {"index", index},
                      {"bytes", bytesForFormalBuffer(formal, paramTypes)},
                      {"meaning",
                       "array read summarized into finite-state projection"}});
          for (const auto &entry : indexAttrs.attrs)
            readRecord.attrs[entry.getKey()] = entry.getValue();
          copySourceAttrs(load, readRecord);
          result.actions.push_back(std::move(readRecord));
        }

        AccessAction projectionAttrs = indexAttrs;
        projectionAttrs.attrs["projection_kind"] = "scalar_low_bit";
        copySourceAttrs(stateExpr, projectionAttrs);
        if (noExactReadEscapes)
          addUniqueStateProjection(result, seenProjections, buffer, index, 2,
                                   projectionAttrs);
      }
    }
  }
}

static void
addPopcountStateProjections(const FunctionFacts &stage, AccessStage &result,
                            const llvm::StringMap<std::string> &paramActual,
                            const llvm::StringMap<std::string> &paramTypes,
                            llvm::StringSet<> &seenReads,
                            llvm::StringSet<> &seenProjections) {
  for (const Fact &load : getFactsByRole(stage, "array_load_var")) {
    std::string loadedVar = getAttr(load, "target");
    std::string formal = getAttr(load, "buffer");
    std::string index = getAttr(load, "index");
    if (loadedVar.empty() || formal.empty() || index.empty())
      continue;

    SmallVector<Fact> popcountUsers;
    for (const Fact &expr : getFactsByRole(stage, "expr_def"))
      if (isPopcountUseOfValue(expr, loadedVar))
        popcountUsers.push_back(expr);
    for (const Fact &store : getFactsByRole(stage, "array_store"))
      if (isPopcountUseOfValue(store, loadedVar))
        popcountUsers.push_back(store);
    if (popcountUsers.empty())
      continue;

    std::string bytesText = bytesForFormalBuffer(formal, paramTypes);
    int64_t bytes = parseInteger(bytesText).value_or(4);
    if (bytes <= 0)
      continue;
    int64_t domain = bytes * 8 + 1;
    std::string buffer = mapBuffer(formal, paramActual);

    AccessAction indexAttrs;
    copyPrefixedAttrs(load, indexAttrs, "index");
    bool noExactReadEscapes =
        popcountProjectionHasNoExactReadEscapes(stage, loadedVar);

    std::string readKey = buffer + "|" + index;
    if (!seenReads.contains(readKey)) {
      seenReads.insert(readKey);
      AccessAction readRecord =
          action({{"kind", "read"},
                  {"buffer", buffer},
                  {"index", index},
                  {"bytes", bytesText},
                  {"meaning",
                   "array read summarized by bounded popcount projection"}});
      for (const auto &entry : indexAttrs.attrs)
        readRecord.attrs[entry.getKey()] = entry.getValue();
      copySourceAttrs(load, readRecord);
      result.actions.push_back(std::move(readRecord));
    }

    AccessAction projectionAttrs = indexAttrs;
    projectionAttrs.attrs["projection_kind"] = "popcount";
    projectionAttrs.attrs["projected_bits"] =
        std::to_string(bitsNeededForDomain(domain));
    copySourceAttrs(popcountUsers.front(), projectionAttrs);
    if (noExactReadEscapes)
      addUniqueStateProjection(result, seenProjections, buffer, index, domain,
                               projectionAttrs);
  }
}

static std::optional<AccessStage> lowerLibraryScan(const FunctionFacts &stage) {
  const Fact *entry = findFactByRole(stage, "entry_call");
  if (!entry || getAttr(*entry, "kind") != "library_scan")
    return std::nullopt;

  SmallVector<std::string> args = splitCSV(getAttr(*entry, "args"));
  std::string input = args.empty() ? "scan_input" : sanitize(args[0]);
  std::string output = args.size() < 2 ? input : sanitize(args[1]);

  AccessStage result;
  result.name = stage.name;
  result.kind = "scan";
  result.recoveryRule =
      "generic host-call lowering: library scan is an explicit stage boundary";
  result.actions.push_back(action({{"kind", "read"},
                                   {"buffer", input},
                                   {"index", "logical"},
                                   {"index_kind", "logical"},
                                   {"bytes", "4"},
                                   {"meaning", "scan input value"}}));
  result.actions.push_back(
      action({{"kind", "write"},
              {"buffer", output},
              {"index", "logical"},
              {"index_kind", "logical"},
              {"bytes", "4"},
              {"meaning", "exclusive scan output value"}}));
  return result;
}

static std::optional<AccessStage>
lowerGenericKernel(const FunctionFacts &stage) {
  const Fact *entry = findFactByRole(stage, "entry_call");
  if (!entry)
    return std::nullopt;

  llvm::StringMap<std::string> paramActual = buildParamActualMap(stage);
  llvm::StringMap<std::string> paramTypes = buildParamTypeMap(stage);

  AccessStage result;
  result.name = stage.name;
  result.kind = "kernel";
  result.recoveryRule =
      "generic lowering: Clang array accesses plus source index aliases";
  for (const Fact &decl : getFactsByRole(stage, "var_decl")) {
    if (!shouldMaterializeIndexDef(stage, decl))
      continue;
    AccessAction record = action({{"kind", "index_def"},
                                  {"name", getAttr(decl, "name")},
                                  {"expr", getAttr(decl, "init")},
                                  {"relation", "ssa"}});
    copyPrefixedAttrs(decl, record, "init");
    result.actions.push_back(std::move(record));
  }

  llvm::StringSet<> seenReads;
  llvm::StringSet<> seenProjections;
  addScalarLowBitStateProjections(stage, result, paramActual, paramTypes,
                                  seenReads, seenProjections);
  addPopcountStateProjections(stage, result, paramActual, paramTypes, seenReads,
                              seenProjections);
  for (const Fact &load : getFactsByRole(stage, "array_load_var")) {
    std::string formal = getAttr(load, "buffer");
    size_t before = result.actions.size();
    addUniqueRead(result, seenReads, mapBuffer(formal, paramActual),
                  getAttr(load, "index"),
                  bytesForFormalBuffer(formal, paramTypes), "array load");
    if (result.actions.size() != before)
      copyPrefixedAttrs(load, result.actions.back(), "index");
    if (result.actions.size() != before)
      copySourceAttrs(load, result.actions.back());
  }

  for (const Fact &expr : getFactsByRole(stage, "expr_def")) {
    int64_t lowBitRefCount =
        parseInteger(getAttr(expr, "low_bit_array_ref_count")).value_or(0);
    for (int64_t i = 0; i < lowBitRefCount; ++i) {
      std::string prefix = "low_bit_array" + std::to_string(i);
      std::string formal = getAttr(expr, prefix + "_buffer");
      std::string index = getAttr(expr, prefix + "_index");
      AccessAction indexAttrs;
      copyPrefixedAttrs(expr, indexAttrs, prefix + "_index", "index");
      bool projectionIsExclusive =
          arrayProjectionHasNoExactReadEscapes(stage, formal, index);
      indexAttrs.attrs["projection_kind"] = "scalar_binary_state";
      std::string buffer = mapBuffer(formal, paramActual);
      std::string readKey = buffer + "|" + index;
      if (!seenReads.contains(readKey)) {
        seenReads.insert(readKey);
        AccessAction readRecord =
            action({{"kind", "read"},
                    {"buffer", buffer},
                    {"index", index},
                    {"bytes", bytesForFormalBuffer(formal, paramTypes)},
                    {"meaning", "array read used by finite-state projection"}});
        for (const auto &entry : indexAttrs.attrs)
          readRecord.attrs[entry.getKey()] = entry.getValue();
        copySourceAttrs(expr, readRecord);
        result.actions.push_back(std::move(readRecord));
      }
      if (projectionIsExclusive)
        addUniqueStateProjection(result, seenProjections, buffer, index, 2,
                                 indexAttrs);
    }

    SmallVector<std::string> buffers = splitCSV(getAttr(expr, "array_buffers"));
    SmallVector<std::string> indices = splitCSV(getAttr(expr, "array_indices"));
    for (size_t i = 0, e = std::min(buffers.size(), indices.size()); i < e;
         ++i) {
      StringRef formal(buffers[i]);
      std::string buffer = mapBuffer(formal, paramActual);
      std::string readKey = buffer + "|" + indices[i];
      if (seenReads.contains(readKey))
        continue;
      seenReads.insert(readKey);
      AccessAction readRecord =
          action({{"kind", "read"},
                  {"buffer", buffer},
                  {"index", indices[i]},
                  {"bytes", bytesForFormalBuffer(formal, paramTypes)},
                  {"meaning", "array read used by scalar expression"}});
      copyPrefixedAttrs(expr, readRecord,
                        std::string("array") + std::to_string(i) + "_index",
                        "index");
      copySourceAttrs(expr, readRecord);
      result.actions.push_back(std::move(readRecord));
    }
  }

  for (const Fact &store : getFactsByRole(stage, "array_store")) {
    if (!hasSourceLocation(store))
      continue;
    std::string formal = getAttr(store, "buffer");
    AccessAction record =
        action({{"kind", "write"},
                {"buffer", mapBuffer(formal, paramActual)},
                {"index", getAttr(store, "index")},
                {"bytes", bytesForFormalBuffer(formal, paramTypes)},
                {"meaning", "array store"}});
    std::string compactIndex = compact(getAttr(store, "index"));
    if (compactIndex.find("fileSize-1") != std::string::npos)
      record.attrs["tail_boundary_write"] = "true";
    copyPrefixedAttrs(store, record, "index");
    copySourceAttrs(store, record);
    result.actions.push_back(std::move(record));
  }

  return result;
}

static std::optional<AccessStage> recoverStage(const FunctionFacts &stage) {
  if (auto result = lowerLibraryScan(stage))
    return result;
  return lowerGenericKernel(stage);
}

static void readFactAttrs(Operation *op, Fact &fact) {
  for (NamedAttribute attr : op->getAttrs()) {
    std::string key = attr.getName().str();
    if (key == "role")
      continue;
    if (auto str = dyn_cast<StringAttr>(attr.getValue())) {
      fact.attrs[key] = str.getValue().str();
    } else if (auto entryKind =
                   dyn_cast<SourceEntryKindAttr>(attr.getValue())) {
      fact.attrs[key] = stringifySourceEntryKind(entryKind.getValue()).str();
    } else if (auto integer = dyn_cast<IntegerAttr>(attr.getValue())) {
      fact.attrs[key] = std::to_string(integer.getInt());
    } else if (auto unit = dyn_cast<UnitAttr>(attr.getValue())) {
      (void)unit;
      fact.attrs[key] = "true";
    }
  }
}

static std::optional<StringRef> sourceFactRole(Operation *op) {
  if (isa<SourceEntryOp>(op))
    return StringRef("entry_call");
  if (isa<SourceFunctionOp>(op))
    return StringRef("function");
  if (isa<SourceParamOp>(op))
    return StringRef("param");
  if (isa<SourceVarDeclOp>(op))
    return StringRef("var_decl");
  if (isa<SourceExprDefOp>(op))
    return StringRef("expr_def");
  if (isa<SourceArrayLoadOp>(op))
    return StringRef("array_load_var");
  if (isa<SourceArrayStoreOp>(op))
    return StringRef("array_store");
  if (isa<SourceLoopOp>(op))
    return StringRef("loop");
  if (isa<SourceCallOp>(op))
    return StringRef("call");
  if (isa<SourceAssignmentOp>(op))
    return StringRef("assignment_or_binary");
  if (isa<SourceArrayAccessOp>(op))
    return StringRef("array_access");
  return std::nullopt;
}

static void normalizeTypedSourceFact(Fact &fact) {
  if (fact.role == "param") {
    if (auto it = fact.attrs.find("type_text"); it != fact.attrs.end())
      fact.attrs["type"] = it->second;
    if (fact.attrs.find("is_pointer") == fact.attrs.end())
      fact.attrs["is_pointer"] = "false";
    if (fact.attrs.find("is_reference") == fact.attrs.end())
      fact.attrs["is_reference"] = "false";
  }
}

static void readFactGroups(PipelineOp pipeline,
                           SmallVectorImpl<FunctionFacts> &stages) {
  auto consumeGroup = [&](Operation *group, StringRef name, StringRef kind,
                          StringRef sourceFunction) {
    FunctionFacts facts;
    facts.name = name.str();
    facts.kind = kind.str();
    facts.sourceFunction =
        sourceFunction.empty() ? facts.name : sourceFunction.str();

    group->walk([&](Operation *op) {
      Fact fact;
      if (isa<FactOp>(op)) {
        fact.role = getStringAttr(op, "role").str();
        readFactAttrs(op, fact);
        facts.facts.push_back(std::move(fact));
        return;
      }
      std::optional<StringRef> role = sourceFactRole(op);
      if (!role)
        return;
      fact.role = role->str();
      readFactAttrs(op, fact);
      normalizeTypedSourceFact(fact);
      facts.facts.push_back(std::move(fact));
    });

    if (facts.kind == "clang_ast_facts")
      stages.push_back(std::move(facts));
  };

  pipeline.walk([&](FactGroupOp group) {
    consumeGroup(
        group.getOperation(),
        getStringAttr(group.getOperation(), SymbolTable::getSymbolAttrName()),
        getStringAttr(group.getOperation(), "kind"),
        getStringAttr(group.getOperation(), "source_function"));
  });
}

static bool parseI64(StringRef text, int64_t &value) {
  return !text.getAsInteger(10, value);
}

static void addI64Attr(OperationState &state, Builder &builder, StringRef key,
                       StringRef value) {
  int64_t parsed = 0;
  if (parseI64(value, parsed))
    state.addAttribute(key, builder.getI64IntegerAttr(parsed));
}

static void addOptionalI64Attrs(OperationState &state, Builder &builder,
                                const AccessAction &record,
                                ArrayRef<StringRef> keys) {
  for (StringRef key : keys)
    addI64Attr(state, builder, key, getAttr(record, key));
}

static void addOptionalUnitAttrs(OperationState &state, Builder &builder,
                                 const AccessAction &record,
                                 ArrayRef<StringRef> keys) {
  for (StringRef key : keys)
    if (!getAttr(record, key).empty())
      state.addAttribute(key, builder.getUnitAttr());
}

static void addOptionalStringAttrs(OperationState &state, Builder &builder,
                                   const AccessAction &record,
                                   ArrayRef<StringRef> keys) {
  for (StringRef key : keys) {
    std::string value = getAttr(record, key);
    if (!value.empty())
      state.addAttribute(key, builder.getStringAttr(value));
  }
}

static void addBufferName(StringRef name, SmallVectorImpl<std::string> &order,
                          llvm::StringSet<> &seen) {
  if (name.empty() || seen.contains(name))
    return;
  seen.insert(name);
  order.push_back(name.str());
}

static void collectBuffers(const AccessAction &record,
                           SmallVectorImpl<std::string> &order,
                           llvm::StringSet<> &seen) {
  addBufferName(getAttr(record, "buffer"), order, seen);
}

static SmallVector<int64_t>
collectPipelineParameterOrdinals(ArrayRef<AccessStage> stages) {
  SmallVector<int64_t> result;
  for (const AccessStage &stage : stages) {
    for (const AccessAction &action : stage.actions) {
      for (const auto &entry : action.attrs) {
        StringRef key = entry.getKey();
        if (!key.ends_with("_kind") || entry.getValue() != "parameter")
          continue;
        std::string sourceKey = key.drop_back(StringRef("_kind").size()).str();
        sourceKey += "_source_arg";
        auto sourceArg = parseInteger(getAttr(action, sourceKey));
        if (sourceArg && !llvm::is_contained(result, *sourceArg))
          result.push_back(*sourceArg);
      }
    }
  }
  llvm::sort(result);
  return result;
}

static bool isSyntheticBufferName(StringRef name) {
  if (!name.consume_front("buf") || name.empty())
    return false;
  return llvm::all_of(name, [](char ch) { return llvm::isDigit(ch); });
}

static bool isMemoryAccessAction(const AccessAction &action) {
  StringRef kind = getAttr(action, "kind");
  return kind == "read" || kind == "write";
}

static void
pruneStageLocalSyntheticBuffers(SmallVectorImpl<AccessStage> &stages) {
  llvm::StringMap<unsigned> firstStage;
  llvm::StringSet<> multiStage;

  for (auto [stageIdx, stage] : llvm::enumerate(stages)) {
    llvm::StringSet<> seenInStage;
    for (const AccessAction &action : stage.actions) {
      if (!isMemoryAccessAction(action))
        continue;
      std::string buffer = getAttr(action, "buffer");
      if (!isSyntheticBufferName(buffer) || seenInStage.contains(buffer))
        continue;
      seenInStage.insert(buffer);

      auto it = firstStage.find(buffer);
      if (it == firstStage.end()) {
        firstStage[buffer] = stageIdx;
      } else if (it->second != stageIdx) {
        multiStage.insert(buffer);
      }
    }
  }

  for (AccessStage &stage : stages) {
    llvm::erase_if(stage.actions, [&](const AccessAction &action) {
      if (!isMemoryAccessAction(action))
        return false;
      std::string buffer = getAttr(action, "buffer");
      return isSyntheticBufferName(buffer) && !multiStage.contains(buffer);
    });
  }
}

static Operation *createBuffer(OpBuilder &builder, Location loc,
                               StringRef name) {
  OperationState state(loc, BufferOp::getOperationName());
  state.addAttribute(SymbolTable::getSymbolAttrName(),
                     builder.getStringAttr(name));
  state.addTypes(BufferType::get(builder.getContext()));
  return builder.create(state);
}

static Value getBufferValue(const llvm::StringMap<Value> &buffers,
                            StringRef name) {
  auto it = buffers.find(name);
  return it == buffers.end() ? Value() : it->second;
}

struct IndexScope {
  llvm::StringMap<Value> named;
  llvm::StringMap<Value> opaque;
  llvm::DenseMap<int64_t, Value> locals;
  const llvm::DenseMap<int64_t, Value> *parameters = nullptr;
  Value logicalIndex;
  Block *parameterBlock = nullptr;
};

static bool isIdentifier(StringRef value) {
  if (value.empty())
    return false;
  if (!std::isalpha(static_cast<unsigned char>(value.front())) &&
      value.front() != '_')
    return false;
  for (char ch : value.drop_front())
    if (!std::isalnum(static_cast<unsigned char>(ch)) && ch != '_')
      return false;
  return true;
}

static Value createLogicalIndex(OpBuilder &builder, Location loc) {
  OperationState state(loc, LogicalIndexOp::getOperationName());
  state.addTypes(builder.getIndexType());
  return builder.create(state)->getResult(0);
}

static Operation *createPipelineParameter(OpBuilder &builder, Location loc,
                                          int64_t sourceArg) {
  OperationState state(loc, ParameterOp::getOperationName());
  state.addAttribute(
      SymbolTable::getSymbolAttrName(),
      builder.getStringAttr("pipeline_arg" + std::to_string(sourceArg)));
  state.addAttribute("source_arg", builder.getI64IntegerAttr(sourceArg));
  state.addTypes(builder.getIndexType());
  return builder.create(state);
}

static Value createStageParameter(OpBuilder &builder, Location loc,
                                  IndexScope &scope) {
  Block *block =
      scope.parameterBlock ? scope.parameterBlock : builder.getInsertionBlock();
  if (!block)
    return Value();
  return block->addArgument(builder.getIndexType(), loc);
}

static gpu::Dimension parseGpuDimension(StringRef dim) {
  if (dim == "y")
    return gpu::Dimension::y;
  if (dim == "z")
    return gpu::Dimension::z;
  return gpu::Dimension::x;
}

static Value createGpuIndex(OpBuilder &builder, Location loc, StringRef source,
                            StringRef dim) {
  gpu::Dimension dimension = parseGpuDimension(dim);
  if (source == "block_id")
    return builder.create<gpu::BlockIdOp>(loc, dimension).getResult();
  if (source == "thread_id")
    return builder.create<gpu::ThreadIdOp>(loc, dimension).getResult();
  if (source == "block_dim")
    return builder.create<gpu::BlockDimOp>(loc, dimension).getResult();
  if (source == "grid_dim")
    return builder.create<gpu::GridDimOp>(loc, dimension).getResult();
  return Value();
}

static Value getOrCreateNamedIndex(OpBuilder &builder, Location loc,
                                   IndexScope &scope, StringRef name) {
  if (name.empty())
    name = "unknown";
  if (auto it = scope.named.find(name); it != scope.named.end())
    return it->second;
  Value value = createStageParameter(builder, loc, scope);
  scope.named[name] = value;
  return value;
}

static Value getOrCreateOpaqueIndex(OpBuilder &builder, Location loc,
                                    IndexScope &scope, StringRef label) {
  if (label.empty())
    label = "unknown";
  if (isIdentifier(label))
    return getOrCreateNamedIndex(builder, loc, scope, label);
  if (auto it = scope.opaque.find(label); it != scope.opaque.end())
    return it->second;
  Value value = createStageParameter(builder, loc, scope);
  scope.opaque[label] = value;
  return value;
}

static Value getOrCreateLocalIndex(OpBuilder &builder, Location loc,
                                   IndexScope &scope, int64_t id) {
  if (auto it = scope.locals.find(id); it != scope.locals.end())
    return it->second;
  Value value = createStageParameter(builder, loc, scope);
  scope.locals[id] = value;
  return value;
}

static std::string attrKey(StringRef prefix, StringRef suffix) {
  std::string key = prefix.str();
  key += suffix.str();
  return key;
}

static Value materializeExprFromAttrs(OpBuilder &builder, Location loc,
                                      IndexScope &scope,
                                      const AccessAction &record,
                                      StringRef prefix, StringRef fallback);

static std::string loopRootIndex(const AccessAction &record);

static Value materializeExprLeaf(OpBuilder &builder, Location loc,
                                 IndexScope &scope, const AccessAction &record,
                                 StringRef prefix) {
  std::string kind = getAttr(record, attrKey(prefix, "_kind"));
  if (kind == "logical")
    return scope.logicalIndex;
  if (kind == "parameter") {
    std::optional<int64_t> sourceArg =
        parseInteger(getAttr(record, attrKey(prefix, "_source_arg")));
    if (!sourceArg || !scope.parameters)
      return Value();
    auto it = scope.parameters->find(*sourceArg);
    return it == scope.parameters->end() ? Value() : it->second;
  }
  if (kind == "local") {
    int64_t id = parseInteger(getAttr(record, attrKey(prefix, "_local_id")))
                     .value_or(-1);
    return getOrCreateLocalIndex(builder, loc, scope, id);
  }
  if (kind == "symbol")
    return getOrCreateNamedIndex(builder, loc, scope,
                                 getAttr(record, attrKey(prefix, "_symbol")));
  if (kind == "const") {
    int64_t value =
        parseInteger(getAttr(record, attrKey(prefix, "_value"))).value_or(0);
    return builder.create<arith::ConstantIndexOp>(loc, value);
  }
  if (kind == "gpu")
    return createGpuIndex(builder, loc,
                          getAttr(record, attrKey(prefix, "_gpu")),
                          getAttr(record, attrKey(prefix, "_dim")));
  return Value();
}

static Location locationFromRecord(MLIRContext *context, Location fallback,
                                   const AccessAction &record) {
  auto line = parseInteger(getAttr(record, "source_line"));
  if (!line)
    return fallback;
  std::string file = getAttr(record, "source_file", "00_cuda_source.cu");
  return FileLineColLoc::get(context, StringRef(file), *line, 0);
}

static Value materializeExprFromAttrs(OpBuilder &builder, Location loc,
                                      IndexScope &scope,
                                      const AccessAction &record,
                                      StringRef prefix, StringRef fallback) {
  std::string kind = getAttr(record, attrKey(prefix, "_kind"));
  if (kind == "logical" || kind == "parameter" || kind == "local" ||
      kind == "symbol" || kind == "const" || kind == "gpu")
    return materializeExprLeaf(builder, loc, scope, record, prefix);

  if (kind == "binary") {
    Value lhs = materializeExprFromAttrs(builder, loc, scope, record,
                                         attrKey(prefix, "_lhs"), fallback);
    Value rhs = materializeExprFromAttrs(builder, loc, scope, record,
                                         attrKey(prefix, "_rhs"), fallback);
    if (lhs && rhs) {
      std::string opcode = getAttr(record, attrKey(prefix, "_opcode"));
      if (opcode == "+")
        return builder.create<arith::AddIOp>(loc, lhs, rhs).getResult();
      if (opcode == "-")
        return builder.create<arith::SubIOp>(loc, lhs, rhs).getResult();
      if (opcode == "*")
        return builder.create<arith::MulIOp>(loc, lhs, rhs).getResult();
      if (opcode == "sdiv")
        return builder.create<arith::DivSIOp>(loc, lhs, rhs).getResult();
      if (opcode == "udiv")
        return builder.create<arith::DivUIOp>(loc, lhs, rhs).getResult();
      if (opcode == "srem")
        return builder.create<arith::RemSIOp>(loc, lhs, rhs).getResult();
      if (opcode == "urem")
        return builder.create<arith::RemUIOp>(loc, lhs, rhs).getResult();
      if (opcode == "ceildiv")
        return builder.create<arith::CeilDivSIOp>(loc, lhs, rhs).getResult();
    }
  }

  return getOrCreateOpaqueIndex(builder, loc, scope, fallback);
}

static void createIndexDef(OpBuilder &builder, Location loc, IndexScope &scope,
                           const AccessAction &record) {
  std::string name = getAttr(record, "name");
  if (name.empty())
    return;

  auto isGpuLeaf = [&](StringRef prefix, StringRef source) {
    return getAttr(record, attrKey(prefix, "_kind")) == "gpu" &&
           getAttr(record, attrKey(prefix, "_gpu")) == source;
  };
  auto isGpuProduct = [&](StringRef prefix) {
    if (getAttr(record, attrKey(prefix, "_kind")) != "binary" ||
        getAttr(record, attrKey(prefix, "_opcode")) != "*")
      return false;
    std::string lhs = attrKey(prefix, "_lhs");
    std::string rhs = attrKey(prefix, "_rhs");
    return (isGpuLeaf(lhs, "block_id") && isGpuLeaf(rhs, "block_dim")) ||
           (isGpuLeaf(rhs, "block_id") && isGpuLeaf(lhs, "block_dim"));
  };
  auto isCudaLogicalIndex = [&]() {
    if (getAttr(record, "init_kind") != "binary" ||
        getAttr(record, "init_opcode") != "+")
      return false;
    return (isGpuProduct("init_lhs") && isGpuLeaf("init_rhs", "thread_id")) ||
           (isGpuProduct("init_rhs") && isGpuLeaf("init_lhs", "thread_id"));
  };

  if (scope.logicalIndex && isCudaLogicalIndex()) {
    scope.named[name] = scope.logicalIndex;
    return;
  }

  std::string kind = getAttr(record, "init_kind");
  if (kind.empty() || kind == "opaque") {
    scope.named[name] = getOrCreateNamedIndex(builder, loc, scope, name);
    return;
  }

  Value expr =
      materializeExprFromAttrs(builder, loc, scope, record, "init", name);
  if (!expr)
    expr = getOrCreateNamedIndex(builder, loc, scope, name);
  scope.named[name] = expr;
}

static Operation *createStageShell(OpBuilder &builder, Location loc,
                                   const AccessStage &stage) {
  OperationState state(loc, stage.kind == "scan"
                                ? ScanOp::getOperationName()
                                : KernelOp::getOperationName());
  state.addAttribute(SymbolTable::getSymbolAttrName(),
                     builder.getStringAttr(stage.name));
  if (stage.kind == "scan")
    state.addAttribute("combiner", builder.getStringAttr("add"));
  Region *region = state.addRegion();
  region->push_back(new Block());
  return builder.create(state);
}

// `index` stays as the source-level typed element index. `byte_index` makes
// the physical byte address explicit, relative to that index operand.
static void addByteIndexAttr(OperationState &state, Builder &builder,
                             const AccessAction &record) {
  std::optional<int64_t> bytes = parseInteger(getAttr(record, "bytes"));
  if (!bytes || *bytes <= 0)
    return;
  AffineExpr byteIndex = getAffineDimExpr(/*position=*/0, builder.getContext());
  if (*bytes != 1)
    byteIndex = byteIndex * *bytes;
  state.addAttribute("byte_index", AffineMapAttr::get(AffineMap::get(
                                       /*dimCount=*/1, /*symbolCount=*/0,
                                       byteIndex, builder.getContext())));
}

static void createStateProjection(OpBuilder &builder, Location loc,
                                  const llvm::StringMap<Value> &buffers,
                                  IndexScope &indices,
                                  const AccessAction &record);

static void createDirectRead(OpBuilder &builder, Location loc,
                             const llvm::StringMap<Value> &buffers,
                             IndexScope &indices, const AccessAction &record) {
  Value buffer = getBufferValue(buffers, getAttr(record, "buffer"));
  if (!buffer)
    return;
  Location opLoc = locationFromRecord(builder.getContext(), loc, record);
  Value index = materializeExprFromAttrs(builder, opLoc, indices, record,
                                         "index", getAttr(record, "index"));
  OperationState state(opLoc, ReadOp::getOperationName());
  state.addOperands({buffer, index});
  addOptionalI64Attrs(state, builder, record, {"bytes"});
  addByteIndexAttr(state, builder, record);
  std::string stateName = getAttr(record, "state");
  if (!stateName.empty())
    state.addAttribute("state",
                       SymbolRefAttr::get(builder.getContext(), stateName));
  if (auto dependency =
          symbolizeReadDependencyKind(getAttr(record, "dependency"))) {
    state.addAttribute("dependency", ReadDependencyKindAttr::get(
                                         builder.getContext(), *dependency));
  }
  if (auto stateKind = symbolizeStateUseKind(getAttr(record, "state_kind"))) {
    state.addAttribute("state_kind",
                       StateUseKindAttr::get(builder.getContext(), *stateKind));
  }
  builder.create(state);
}

static void createRead(OpBuilder &builder, Location loc,
                       const llvm::StringMap<Value> &buffers,
                       IndexScope &indices, const AccessAction &record,
                       const AccessAction *projection = nullptr) {
  if (!record.hasUnboundedIteration)
    return createDirectRead(builder, loc, buffers, indices, record);

  Location opLoc = locationFromRecord(builder.getContext(), loc, record);
  Value logical = indices.logicalIndex;
  if (!logical) {
    logical = createLogicalIndex(builder, opLoc);
    indices.logicalIndex = logical;
  }
  Value initial;
  if (!getAttr(record, "unbounded_seed_kind").empty())
    initial = materializeExprFromAttrs(builder, opLoc, indices, record,
                                       "unbounded_seed", "walk_seed");
  if (!initial) {
    // Backward compatibility for hand-written recovery facts that predate
    // explicit seed provenance.  Generic MLIR recovery always records the
    // actual source scf.while operand.
    Value one = builder.create<arith::ConstantIndexOp>(opLoc, 1);
    initial = builder.create<arith::SubIOp>(opLoc, logical, one);
  }
  std::string carriedName = loopRootIndex(record);
  if (carriedName.empty())
    carriedName = "walk_index";
  std::optional<int64_t> carriedLocalId;
  std::function<std::optional<int64_t>(StringRef)> findLocalId =
      [&](StringRef prefix) -> std::optional<int64_t> {
    std::string kind = getAttr(record, attrKey(prefix, "_kind"));
    if (kind == "local")
      return parseInteger(getAttr(record, attrKey(prefix, "_local_id")));
    if (kind != "binary")
      return std::nullopt;
    if (auto lhs = findLocalId(attrKey(prefix, "_lhs")))
      return lhs;
    return findLocalId(attrKey(prefix, "_rhs"));
  };
  carriedLocalId = findLocalId("index");

  builder.create<scf::WhileOp>(
      opLoc, TypeRange{builder.getIndexType()}, ValueRange{initial},
      [&](OpBuilder &beforeBuilder, Location beforeLoc, ValueRange args) {
        Value zero = beforeBuilder.create<arith::ConstantIndexOp>(beforeLoc, 0);
        Value inRange = beforeBuilder.create<arith::CmpIOp>(
            beforeLoc, arith::CmpIPredicate::sge, args.front(), zero);
        beforeBuilder.create<scf::ConditionOp>(beforeLoc, inRange, args);
      },
      [&](OpBuilder &afterBuilder, Location afterLoc, ValueRange args) {
        IndexScope loopIndices = indices;
        if (carriedLocalId)
          loopIndices.locals[*carriedLocalId] = args.front();
        else
          loopIndices.named[carriedName] = args.front();
        AccessAction direct = record;
        direct.hasUnboundedIteration = false;
        createDirectRead(afterBuilder, afterLoc, buffers, loopIndices, direct);
        if (projection) {
          // The source loop proves a finite projection of this exact dynamic
          // read.  Keep the projection beside the read inside the reconstructed
          // loop so access-ID assignment can link them without losing the
          // finite-state evidence when the original Polygeist loop is erased.
          AccessAction directProjection = *projection;
          directProjection.hasUnboundedIteration = false;
          createStateProjection(afterBuilder, afterLoc, buffers, loopIndices,
                                directProjection);
        }
        Value step = afterBuilder.create<arith::ConstantIndexOp>(afterLoc, 1);
        Value next =
            afterBuilder.create<arith::SubIOp>(afterLoc, args.front(), step);
        afterBuilder.create<scf::YieldOp>(afterLoc, next);
      });
}

static void createWrite(OpBuilder &builder, Location loc,
                        const llvm::StringMap<Value> &buffers,
                        IndexScope &indices, const AccessAction &record) {
  Value buffer = getBufferValue(buffers, getAttr(record, "buffer"));
  if (!buffer)
    return;
  Location opLoc = locationFromRecord(builder.getContext(), loc, record);
  Value index = materializeExprFromAttrs(builder, opLoc, indices, record,
                                         "index", getAttr(record, "index"));
  OperationState state(opLoc, WriteOp::getOperationName());
  state.addOperands({buffer, index});
  addOptionalI64Attrs(state, builder, record, {"bytes", "value_domain"});
  addByteIndexAttr(state, builder, record);
  addOptionalUnitAttrs(state, builder, record, {"tail_boundary_write"});
  builder.create(state);
}

static void createStateProjection(OpBuilder &builder, Location loc,
                                  const llvm::StringMap<Value> &buffers,
                                  IndexScope &indices,
                                  const AccessAction &record) {
  Value buffer = getBufferValue(buffers, getAttr(record, "buffer"));
  if (!buffer)
    return;
  // A standalone dynamic projection cannot be placed correctly because its
  // loop-carried index is scoped inside the reconstructed scf.while.  When the
  // source value flow proves such a projection, materializeActionsDirectly
  // pairs it with the corresponding read and createRead emits both in-loop.
  if (record.hasUnboundedIteration)
    return;
  Location opLoc = locationFromRecord(builder.getContext(), loc, record);
  Value index = materializeExprFromAttrs(builder, opLoc, indices, record,
                                         "index", getAttr(record, "index"));
  OperationState state(opLoc, ProjectStateOp::getOperationName());
  state.addOperands({buffer, index});
  addI64Attr(state, builder, "domain", getAttr(record, "domain", "2"));
  addI64Attr(state, builder, "modulus", getAttr(record, "modulus", "2"));
  addI64Attr(state, builder, "projected_bits",
             getAttr(record, "projected_bits"));
  addOptionalStringAttrs(state, builder, record, {"projection_kind"});
  builder.create(state);
}

static void createAdvance(OpBuilder &builder, Location loc,
                          const AccessAction &record) {
  OperationState state(loc, AdvanceOp::getOperationName());
  state.addAttribute("direction",
                     builder.getStringAttr(getAttr(record, "direction")));
  addI64Attr(state, builder, "distance", getAttr(record, "distance", "0"));
  addI64Attr(state, builder, "count", getAttr(record, "count"));
  if (std::string callee = getAttr(record, "callee"); !callee.empty())
    state.addAttribute("callee", builder.getStringAttr(callee));
  addOptionalUnitAttrs(state, builder, record, {"sync"});
  builder.create(state);
}

static void materializeAction(OpBuilder &builder, Location loc,
                              const llvm::StringMap<Value> &buffers,
                              IndexScope &indices, const AccessAction &record) {
  std::string kind = getAttr(record, "kind");
  if (kind == "index_def")
    return createIndexDef(builder, loc, indices, record);
  if (kind == "read")
    return createRead(builder, loc, buffers, indices, record);
  if (kind == "write")
    return createWrite(builder, loc, buffers, indices, record);
  if (kind == "state_projection")
    return createStateProjection(builder, loc, buffers, indices, record);
  if (kind == "advance")
    return createAdvance(builder, loc, record);
}

static std::string rootIndexSymbolFromExpr(const AccessAction &record,
                                           StringRef prefix) {
  std::string kind = getAttr(record, attrKey(prefix, "_kind"));
  if (kind == "symbol")
    return getAttr(record, attrKey(prefix, "_symbol"));
  if (kind == "binary") {
    std::string lhs = rootIndexSymbolFromExpr(record, attrKey(prefix, "_lhs"));
    if (!lhs.empty())
      return lhs;
    return rootIndexSymbolFromExpr(record, attrKey(prefix, "_rhs"));
  }
  return "";
}

static std::string loopRootIndex(const AccessAction &record) {
  std::string root = rootIndexSymbolFromExpr(record, "index");
  if (!root.empty())
    return root;

  std::string index = getAttr(record, "index");
  if (isIdentifier(index))
    return index;
  return "";
}

static void materializeActionsDirectly(OpBuilder &builder, Location loc,
                                       const llvm::StringMap<Value> &buffers,
                                       IndexScope &indices,
                                       ArrayRef<AccessAction> actions) {
  indices.parameterBlock = builder.getInsertionBlock();
  indices.logicalIndex = createLogicalIndex(builder, loc);
  for (size_t i = 0; i < actions.size(); ++i) {
    const AccessAction &act = actions[i];
    if (getAttr(act, "kind") == "read" && act.hasUnboundedIteration &&
        i + 1 < actions.size()) {
      const AccessAction &projection = actions[i + 1];
      if (getAttr(projection, "kind") == "state_projection" &&
          projection.hasUnboundedIteration &&
          getAttr(projection, "buffer") == getAttr(act, "buffer") &&
          getAttr(projection, "index") == getAttr(act, "index")) {
        createRead(builder, loc, buffers, indices, act, &projection);
        ++i;
        continue;
      }
    }
    materializeAction(builder, loc, buffers, indices, act);
  }
}

static bool isMaterializedIndexExpressionOp(Operation *op) {
  if (!op)
    return false;
  StringRef name = op->getName().getStringRef();
  return name == "arith.constant" || name == "arith.addi" ||
         name == "arith.subi" || name == "arith.muli" ||
         name == "arith.divsi" || name == "arith.divui" ||
         name == "arith.remsi" || name == "arith.remui" ||
         name == "arith.ceildivsi" || name == "arith.index_cast" ||
         name == "arith.index_castui" || name == "gpu.block_id" ||
         name == "gpu.thread_id" || name == "gpu.block_dim" ||
         name == "gpu.grid_dim";
}

// Read and projection materialization intentionally builds separate arithmetic
// operations from the same recovered index expression.  Match only that small,
// pure expression language; opaque block arguments and all other operations
// must be the identical SSA value.
static bool sameMaterializedIndex(Value lhs, Value rhs, unsigned depth = 0) {
  if (lhs == rhs)
    return true;
  if (!lhs || !rhs || lhs.getType() != rhs.getType() || depth > 16)
    return false;

  Operation *lhsDef = lhs.getDefiningOp();
  Operation *rhsDef = rhs.getDefiningOp();
  if (!lhsDef || !rhsDef || !isMaterializedIndexExpressionOp(lhsDef) ||
      !isMaterializedIndexExpressionOp(rhsDef) ||
      lhsDef->getName() != rhsDef->getName() ||
      lhsDef->getAttrDictionary() != rhsDef->getAttrDictionary() ||
      lhsDef->getNumOperands() != rhsDef->getNumOperands())
    return false;

  for (auto [lhsOperand, rhsOperand] :
       llvm::zip(lhsDef->getOperands(), rhsDef->getOperands()))
    if (!sameMaterializedIndex(lhsOperand, rhsOperand, depth + 1))
      return false;
  return true;
}

static void assignAccessIds(PipelineOp pipeline) {
  int64_t ordinal = 0;
  pipeline.getBody().walk([&](Operation *op) {
    if (!isa<ReadOp, WriteOp>(op))
      return;
    op->setAttr("access_id", StringAttr::get(op->getContext(),
                                             "a" + std::to_string(ordinal++)));
  });

  // A project_state is evidence about one concrete read, not a second memory
  // access.  Recovery emits it immediately after that read, so attach the
  // read's stable ID once lexical IDs have been assigned.
  pipeline.getBody().walk([&](ProjectStateOp projection) {
    for (Operation *previous = projection->getPrevNode(); previous;
         previous = previous->getPrevNode()) {
      auto read = dyn_cast<ReadOp>(previous);
      if (!read || read.getBuffer() != projection.getBuffer() ||
          !sameMaterializedIndex(read.getIndex(), projection.getIndex()))
        continue;
      auto id = read.getOperation()->getAttrOfType<StringAttr>("access_id");
      if (id)
        projection.getOperation()->setAttr("read_access", id);
      break;
    }
  });
}

struct WhileCoordinate {
  Operation *loop = nullptr;
  unsigned beforeLane = 0;
  unsigned afterLane = 0;
};

struct GenericRaisingContext {
  llvm::DenseMap<Value, std::string> valueNames;
  llvm::DenseMap<Value, Value> valueAliases;
  llvm::DenseMap<Value, Value> memrefSlotAliases;
  llvm::DenseMap<Value, int64_t> stageLocalIds;
  int64_t nextValueName = 0;
  int64_t nextStageLocalId = 0;
  func::FuncOp rootDriver;
  scf::ForOp topLevelFor;
  Operation *logicalLoop = nullptr;
  SmallVector<WhileCoordinate, 2> logicalWhileCoordinates;
  bool enableBitGenLinearizedStreams = false;
};

static bool isBitGenLikeName(StringRef name) {
  return name.contains("KernelGenerated") || name.contains("regex") ||
         name.contains("bitgen") || name.contains("BitGen");
}

static Value resolveAlias(Value value, GenericRaisingContext &ctx) {
  llvm::SmallPtrSet<Value, 8> seen;
  while (value) {
    auto it = ctx.valueAliases.find(value);
    if (it == ctx.valueAliases.end() || !it->second ||
        !seen.insert(value).second)
      return value;
    value = it->second;
  }
  return value;
}

static std::string getOrCreateValueName(GenericRaisingContext &ctx, Value value,
                                        StringRef prefix = "v") {
  if (!value)
    return "unknown";
  value = resolveAlias(value, ctx);
  if (auto arg = dyn_cast<BlockArgument>(value)) {
    if (ctx.rootDriver && arg.getOwner() == &ctx.rootDriver.front())
      return "pipeline_arg" + std::to_string(arg.getArgNumber());
  }
  auto it = ctx.valueNames.find(value);
  if (it != ctx.valueNames.end())
    return it->second;
  std::string name = (prefix + Twine(ctx.nextValueName++)).str();
  ctx.valueNames[value] = name;
  return name;
}

static int64_t getOrCreateStageLocalId(GenericRaisingContext &ctx,
                                       Value value) {
  value = resolveAlias(value, ctx);
  auto it = ctx.stageLocalIds.find(value);
  if (it != ctx.stageLocalIds.end())
    return it->second;
  int64_t id = ctx.nextStageLocalId++;
  ctx.stageLocalIds[value] = id;
  return id;
}

static bool isOneConstant(Value value) {
  APInt intValue;
  return matchPattern(value, m_ConstantInt(&intValue)) && intValue == 1;
}

static bool isAllOnesConstant(Value value) {
  APInt intValue;
  return matchPattern(value, m_ConstantInt(&intValue)) && intValue.isAllOnes();
}

static std::optional<int64_t> integerConstant(Value value) {
  APInt intValue;
  if (!matchPattern(value, m_ConstantInt(&intValue)))
    return std::nullopt;
  return intValue.getSExtValue();
}

static Value stripIndexAndIntegerCasts(Value value);

static std::optional<int64_t> integerConstant(Value value,
                                              GenericRaisingContext &ctx) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  return integerConstant(value);
}

static std::optional<bool> knownBoolValue(Value value,
                                          GenericRaisingContext &ctx) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  if (!value)
    return std::nullopt;

  if (std::optional<int64_t> constant = integerConstant(value))
    return *constant != 0;

  auto cmp = value.getDefiningOp<arith::CmpIOp>();
  if (!cmp)
    return std::nullopt;

  std::optional<int64_t> lhs = integerConstant(cmp.getLhs(), ctx);
  std::optional<int64_t> rhs = integerConstant(cmp.getRhs(), ctx);
  if (!lhs || !rhs)
    return std::nullopt;

  switch (cmp.getPredicate()) {
  case arith::CmpIPredicate::eq:
    return *lhs == *rhs;
  case arith::CmpIPredicate::ne:
    return *lhs != *rhs;
  case arith::CmpIPredicate::slt:
  case arith::CmpIPredicate::ult:
    return *lhs < *rhs;
  case arith::CmpIPredicate::sle:
  case arith::CmpIPredicate::ule:
    return *lhs <= *rhs;
  case arith::CmpIPredicate::sgt:
  case arith::CmpIPredicate::ugt:
    return *lhs > *rhs;
  case arith::CmpIPredicate::sge:
  case arith::CmpIPredicate::uge:
    return *lhs >= *rhs;
  }
  return std::nullopt;
}

static bool isInsideKnownDeadIf(Operation *op, GenericRaisingContext &ctx) {
  Operation *child = op;
  while (child) {
    Operation *parent = child->getParentOp();
    if (!parent)
      return false;

    if (auto ifOp = dyn_cast<scf::IfOp>(parent)) {
      std::optional<bool> condition = knownBoolValue(ifOp.getCondition(), ctx);
      if (condition) {
        Region *region = child->getParentRegion();
        bool inThen = region == &ifOp.getThenRegion();
        bool inElse = region == &ifOp.getElseRegion();
        if ((*condition && inElse) || (!*condition && inThen))
          return true;
      }
    }

    child = parent;
  }
  return false;
}

static bool sameValueOrIndexCast(Value value, Value expected) {
  if (value == expected)
    return true;
  if (auto cast = value.getDefiningOp<arith::IndexCastOp>())
    return sameValueOrIndexCast(cast.getIn(), expected);
  if (auto cast = value.getDefiningOp<arith::IndexCastUIOp>())
    return sameValueOrIndexCast(cast.getIn(), expected);
  return false;
}

static Value stripIndexAndIntegerCasts(Value value) {
  while (value) {
    if (auto cast = value.getDefiningOp<arith::IndexCastOp>()) {
      value = cast.getIn();
      continue;
    }
    if (auto cast = value.getDefiningOp<arith::IndexCastUIOp>()) {
      value = cast.getIn();
      continue;
    }
    if (auto cast = value.getDefiningOp<arith::ExtSIOp>()) {
      value = cast.getIn();
      continue;
    }
    if (auto cast = value.getDefiningOp<arith::ExtUIOp>()) {
      value = cast.getIn();
      continue;
    }
    if (auto cast = value.getDefiningOp<arith::TruncIOp>()) {
      value = cast.getIn();
      continue;
    }
    return value;
  }
  return {};
}

static bool isCudaIndexGlobalName(StringRef name) {
  return name == "blockIdx" || name == "blockDim" || name == "threadIdx" ||
         name == "gridDim";
}

static bool affineMapIsConstantZero(AffineMap map);

static std::optional<int64_t> evaluateConstantAffineExpr(AffineExpr expr,
                                                         AffineMap map,
                                                         ValueRange operands) {
  if (auto constant = expr.dyn_cast<AffineConstantExpr>())
    return constant.getValue();
  if (auto dim = expr.dyn_cast<AffineDimExpr>()) {
    unsigned position = dim.getPosition();
    if (position >= map.getNumDims() || position >= operands.size())
      return std::nullopt;
    return integerConstant(stripIndexAndIntegerCasts(operands[position]));
  }
  if (auto symbol = expr.dyn_cast<AffineSymbolExpr>()) {
    unsigned position = map.getNumDims() + symbol.getPosition();
    if (symbol.getPosition() >= map.getNumSymbols() ||
        position >= operands.size())
      return std::nullopt;
    return integerConstant(stripIndexAndIntegerCasts(operands[position]));
  }

  auto binary = expr.dyn_cast<AffineBinaryOpExpr>();
  if (!binary)
    return std::nullopt;
  std::optional<int64_t> lhs =
      evaluateConstantAffineExpr(binary.getLHS(), map, operands);
  std::optional<int64_t> rhs =
      evaluateConstantAffineExpr(binary.getRHS(), map, operands);
  if (!lhs || !rhs)
    return std::nullopt;
  if (binary.getKind() == AffineExprKind::Add)
    return *lhs + *rhs;
  if (binary.getKind() == AffineExprKind::Mul)
    return *lhs * *rhs;
  return std::nullopt;
}

static bool affineAccessEvaluatesToAllZero(AffineMap map, ValueRange operands) {
  if (map.getNumResults() == 0 ||
      operands.size() != map.getNumDims() + map.getNumSymbols())
    return false;
  for (AffineExpr result : map.getResults()) {
    std::optional<int64_t> value =
        evaluateConstantAffineExpr(result, map, operands);
    if (!value || *value != 0)
      return false;
  }
  return true;
}

static Value stripPolygeistMemRefViews(Value value) {
  llvm::SmallPtrSet<Value, 8> seen;
  while (value && seen.insert(value).second) {
    Operation *def = value.getDefiningOp();
    if (!def)
      return value;
    if (auto cast = dyn_cast<memref::CastOp>(def)) {
      value = cast.getSource();
      continue;
    }
    StringRef name = def->getName().getStringRef();
    if (name == "polygeist.subindex" && def->getNumOperands() >= 2) {
      std::optional<int64_t> offset =
          integerConstant(stripIndexAndIntegerCasts(def->getOperand(1)));
      if (!offset || *offset != 0)
        return {};
      value = def->getOperand(0);
      continue;
    }
    if ((name == "polygeist.pointer2memref" ||
         name == "polygeist.memref2pointer") &&
        def->getNumOperands() >= 1) {
      value = def->getOperand(0);
      continue;
    }
    return value;
  }
  return value;
}

static bool isPolygeistGpuGlobalLoad(Value value, StringRef globalName) {
  value = stripIndexAndIntegerCasts(value);
  if (!value)
    return false;
  if (globalName == "blockIdx")
    if (auto id = value.getDefiningOp<gpu::BlockIdOp>())
      return id.getDimension() == gpu::Dimension::x;
  if (globalName == "blockDim")
    if (auto dim = value.getDefiningOp<gpu::BlockDimOp>())
      return dim.getDimension() == gpu::Dimension::x;
  if (globalName == "threadIdx")
    if (auto id = value.getDefiningOp<gpu::ThreadIdOp>())
      return id.getDimension() == gpu::Dimension::x;
  if (globalName == "gridDim")
    if (auto dim = value.getDefiningOp<gpu::GridDimOp>())
      return dim.getDimension() == gpu::Dimension::x;
  auto load = value ? value.getDefiningOp<affine::AffineLoadOp>() : nullptr;
  if (!load || !affineAccessEvaluatesToAllZero(load.getAffineMap(),
                                               load.getMapOperands()))
    return false;
  Value root = stripPolygeistMemRefViews(load.getMemref());
  auto getGlobal = root ? root.getDefiningOp<memref::GetGlobalOp>() : nullptr;
  return getGlobal && getGlobal.getName() == globalName;
}

static bool isBlockIdTimesBlockDim(Value value) {
  value = stripIndexAndIntegerCasts(value);
  auto mul = value ? value.getDefiningOp<arith::MulIOp>() : nullptr;
  if (!mul)
    return false;
  return (isPolygeistGpuGlobalLoad(mul.getLhs(), "blockIdx") &&
          isPolygeistGpuGlobalLoad(mul.getRhs(), "blockDim")) ||
         (isPolygeistGpuGlobalLoad(mul.getRhs(), "blockIdx") &&
          isPolygeistGpuGlobalLoad(mul.getLhs(), "blockDim"));
}

static bool isCudaGlobalThreadIndex(Value value, GenericRaisingContext &ctx) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  auto add = value ? value.getDefiningOp<arith::AddIOp>() : nullptr;
  if (!add)
    return false;
  return (isBlockIdTimesBlockDim(add.getLhs()) &&
          isPolygeistGpuGlobalLoad(add.getRhs(), "threadIdx")) ||
         (isBlockIdTimesBlockDim(add.getRhs()) &&
          isPolygeistGpuGlobalLoad(add.getLhs(), "threadIdx"));
}

static bool isCudaGridStride(Value value) {
  value = stripIndexAndIntegerCasts(value);
  auto mul = value ? value.getDefiningOp<arith::MulIOp>() : nullptr;
  if (!mul)
    return false;
  return (isPolygeistGpuGlobalLoad(mul.getLhs(), "blockDim") &&
          isPolygeistGpuGlobalLoad(mul.getRhs(), "gridDim")) ||
         (isPolygeistGpuGlobalLoad(mul.getRhs(), "blockDim") &&
          isPolygeistGpuGlobalLoad(mul.getLhs(), "gridDim"));
}

static bool isGridStrideCanonicalIndex(Value value, scf::ForOp loop) {
  if (!loop)
    return false;
  if (sameValueOrIndexCast(value, loop.getInductionVar()))
    return true;

  if (auto cast = value.getDefiningOp<arith::IndexCastOp>())
    return isGridStrideCanonicalIndex(cast.getIn(), loop);
  if (auto cast = value.getDefiningOp<arith::IndexCastUIOp>())
    return isGridStrideCanonicalIndex(cast.getIn(), loop);

  // Polygeist often canonicalizes a grid-stride loop IV as:
  //   base + ((iv - base) / step) * step
  // which is equal to the scf.for induction variable. Collapse this back to
  // the logical per-stage index `i` so later dependence analysis compares
  // stages rather than opaque temporary values.
  auto add = value.getDefiningOp<arith::AddIOp>();
  if (!add)
    return false;
  auto mul = add.getRhs().getDefiningOp<arith::MulIOp>();
  if (!mul)
    return false;
  auto div = mul.getLhs().getDefiningOp<arith::DivUIOp>();
  if (!div)
    return false;
  auto sub = div.getLhs().getDefiningOp<arith::SubIOp>();
  if (!sub)
    return false;
  return sameValueOrIndexCast(sub.getLhs(), loop.getInductionVar()) &&
         add.getLhs() == sub.getRhs() && mul.getRhs() == div.getRhs();
}

static bool isProvenCudaGridStrideLoop(scf::ForOp loop,
                                       GenericRaisingContext &ctx) {
  return loop && isCudaGlobalThreadIndex(loop.getLowerBound(), ctx) &&
         isCudaGridStride(loop.getStep());
}

static bool isMinusOneUpdate(Value value, Value carried = Value()) {
  value = stripIndexAndIntegerCasts(value);
  carried = stripIndexAndIntegerCasts(carried);

  if (auto add = value.getDefiningOp<arith::AddIOp>()) {
    if (auto rhs = integerConstant(stripIndexAndIntegerCasts(add.getRhs()));
        rhs && *rhs == -1)
      return !carried || sameValueOrIndexCast(add.getLhs(), carried);
    if (auto lhs = integerConstant(stripIndexAndIntegerCasts(add.getLhs()));
        lhs && *lhs == -1)
      return !carried || sameValueOrIndexCast(add.getRhs(), carried);
  }

  if (auto sub = value.getDefiningOp<arith::SubIOp>()) {
    if (auto rhs = integerConstant(stripIndexAndIntegerCasts(sub.getRhs()));
        rhs && *rhs == 1)
      return !carried || sameValueOrIndexCast(sub.getLhs(), carried);
  }

  return false;
}

static bool isPlusOneUpdate(Value value, Value carried) {
  value = stripIndexAndIntegerCasts(value);
  carried = stripIndexAndIntegerCasts(carried);
  auto add = value ? value.getDefiningOp<arith::AddIOp>() : nullptr;
  if (!add || !carried)
    return false;
  if (auto rhs = integerConstant(stripIndexAndIntegerCasts(add.getRhs()));
      rhs && *rhs == 1)
    return sameValueOrIndexCast(add.getLhs(), carried);
  if (auto lhs = integerConstant(stripIndexAndIntegerCasts(add.getLhs()));
      lhs && *lhs == 1)
    return sameValueOrIndexCast(add.getRhs(), carried);
  return false;
}

static Value dataDependentBackwardWalkSeed(Value value) {
  value = stripIndexAndIntegerCasts(value);
  auto arg = dyn_cast_or_null<BlockArgument>(value);
  if (!arg)
    return {};

  Operation *whileOp = arg.getOwner()->getParentOp();
  if (!isa_and_nonnull<scf::WhileOp>(whileOp) || whileOp->getNumRegions() < 2)
    return {};

  unsigned argNo = arg.getArgNumber();
  if (whileOp->getNumOperands() <= argNo)
    return {};

  // Seed proof: the carried predecessor index starts from current_index - 1,
  // e.g. j = k - 1 before entering the lookback loop.
  Value seed = whileOp->getOperand(argNo);
  if (!isMinusOneUpdate(seed))
    return {};

  // Update proof: each loop step walks further backward, e.g. --j.
  Region &after = whileOp->getRegion(1);
  if (after.empty())
    return {};
  Operation *yield = after.front().getTerminator();
  if (!yield || yield->getName().getStringRef() != "scf.yield" ||
      yield->getNumOperands() <= argNo)
    return {};

  if (!isMinusOneUpdate(yield->getOperand(argNo), arg))
    return {};
  return seed;
}

static bool isDataDependentBackwardWalkIndex(Value value) {
  return static_cast<bool>(dataDependentBackwardWalkSeed(value));
}

static bool hasDataDependentBackwardWalkIndex(ArrayRef<Value> values) {
  for (Value value : values)
    if (isDataDependentBackwardWalkIndex(value))
      return true;
  return false;
}

static Value dataDependentBackwardWalkSeed(ArrayRef<Value> values) {
  for (Value value : values)
    if (Value seed = dataDependentBackwardWalkSeed(value))
      return seed;
  return {};
}

static bool isPrimaryCoordinateLoop(Operation *op, GenericRaisingContext &ctx) {
  if (auto loop = dyn_cast<affine::AffineForOp>(op))
    return loop.getStep() == 1;
  if (auto loop = dyn_cast<affine::AffineParallelOp>(op)) {
    auto steps = loop.getSteps();
    return loop.getNumDims() == 1 && loop.getIVs().size() == 1 &&
           steps.size() == 1 && steps.front() == 1;
  }
  if (auto loop = dyn_cast<scf::ForOp>(op)) {
    std::optional<int64_t> step = integerConstant(loop.getStep(), ctx);
    return (step && *step == 1) || isProvenCudaGridStrideLoop(loop, ctx);
  }
  if (auto loop = dyn_cast<scf::ParallelOp>(op)) {
    if (loop.getInductionVars().size() != 1 || loop.getStep().size() != 1)
      return false;
    std::optional<int64_t> step = integerConstant(loop.getStep().front(), ctx);
    return step && *step == 1;
  }
  return false;
}

static bool selectPrimaryCoordinateLoop(GenericRaisingContext &ctx,
                                        Operation *loop) {
  ctx.logicalLoop = nullptr;
  ctx.topLevelFor = nullptr;
  ctx.logicalWhileCoordinates.clear();
  if (!isPrimaryCoordinateLoop(loop, ctx))
    return false;
  ctx.logicalLoop = loop;
  if (auto forLoop = dyn_cast<scf::ForOp>(loop))
    ctx.topLevelFor = forLoop;
  return true;
}

static bool isLoopOperation(Operation *op) {
  return isa<affine::AffineForOp, affine::AffineParallelOp, scf::ForOp,
             scf::ParallelOp, scf::WhileOp>(op);
}

static bool hasLoopAncestorWithin(Operation *op, Operation *root) {
  for (Operation *parent = op->getParentOp(); parent;
       parent = parent->getParentOp()) {
    if (parent == root)
      return false;
    if (isLoopOperation(parent))
      return true;
  }
  return true;
}

static void selectUniqueTopLevelCoordinateLoop(Operation *root,
                                               GenericRaisingContext &ctx) {
  ctx.logicalLoop = nullptr;
  ctx.topLevelFor = nullptr;
  ctx.logicalWhileCoordinates.clear();
  Operation *candidate = nullptr;
  bool ambiguous = false;
  root->walk([&](Operation *op) {
    if (ambiguous || !isLoopOperation(op) || hasLoopAncestorWithin(op, root) ||
        !isPrimaryCoordinateLoop(op, ctx))
      return;
    if (candidate) {
      ambiguous = true;
      return;
    }
    candidate = op;
  });
  if (!ambiguous && candidate)
    selectPrimaryCoordinateLoop(ctx, candidate);
}

struct CoordinateDerivation {
  bool valid = false;
  bool dependsOnScheduler = false;
};

// Prove that a loop seed is linear in the CUDA scheduling coordinate, with
// arbitrary loop-invariant scalar coefficients. This is deliberately narrower
// than merely finding the scheduler somewhere in the SSA tree: i*i, a
// coordinate divisor, and data-dependent operations are rejected.
static CoordinateDerivation analyzeCoordinateDerivation(
    Value value, GenericRaisingContext &ctx, scf::ForOp schedulingLoop,
    llvm::SmallPtrSetImpl<Value> &active, unsigned depth = 0) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  if (!value || depth > 24 || !active.insert(value).second)
    return {};

  auto finish = [&](CoordinateDerivation result) {
    active.erase(value);
    return result;
  };
  if ((schedulingLoop && isGridStrideCanonicalIndex(value, schedulingLoop)) ||
      isCudaGlobalThreadIndex(value, ctx))
    return finish({true, true});
  if (integerConstant(value))
    return finish({true, false});

  // Function/driver arguments and CUDA launch dimensions are invariant
  // coefficients. Individual block/thread coordinates are not accepted as
  // invariant leaves; the full CUDA global thread expression is recognized
  // above.
  if (isa<BlockArgument>(value))
    return finish({true, false});
  for (StringRef source : {StringRef("blockDim"), StringRef("gridDim")})
    if (isPolygeistGpuGlobalLoad(value, source))
      return finish({true, false});

  Operation *def = value.getDefiningOp();
  if (!def || def->getNumOperands() != 2)
    return finish({});
  CoordinateDerivation lhs = analyzeCoordinateDerivation(
      def->getOperand(0), ctx, schedulingLoop, active, depth + 1);
  CoordinateDerivation rhs = analyzeCoordinateDerivation(
      def->getOperand(1), ctx, schedulingLoop, active, depth + 1);
  if (!lhs.valid || !rhs.valid)
    return finish({});

  if (isa<arith::AddIOp, arith::SubIOp>(def))
    return finish({true, lhs.dependsOnScheduler || rhs.dependsOnScheduler});
  if (isa<arith::MulIOp>(def)) {
    if (lhs.dependsOnScheduler && rhs.dependsOnScheduler)
      return finish({});
    return finish({true, lhs.dependsOnScheduler || rhs.dependsOnScheduler});
  }
  if (isa<arith::DivSIOp, arith::DivUIOp, arith::RemSIOp, arith::RemUIOp>(
          def)) {
    if (rhs.dependsOnScheduler)
      return finish({});
    if (lhs.dependsOnScheduler) {
      std::optional<int64_t> divisor = integerConstant(def->getOperand(1), ctx);
      if (!divisor || *divisor <= 0)
        return finish({});
    }
    return finish({true, lhs.dependsOnScheduler});
  }
  if (isa<arith::ShLIOp, arith::ShRSIOp, arith::ShRUIOp>(def)) {
    if (rhs.dependsOnScheduler || !integerConstant(def->getOperand(1), ctx))
      return finish({});
    return finish({true, lhs.dependsOnScheduler});
  }
  return finish({});
}

static bool isCoordinateSeed(Value value, GenericRaisingContext &ctx) {
  if (integerConstant(value, ctx))
    return true;
  llvm::SmallPtrSet<Value, 16> active;
  CoordinateDerivation derivation =
      analyzeCoordinateDerivation(value, ctx, ctx.topLevelFor, active);
  return derivation.valid && derivation.dependsOnScheduler;
}

static std::optional<WhileCoordinate>
findUniqueDataCoordinate(scf::WhileOp loop, GenericRaisingContext &ctx) {
  if (!loop || loop->getNumRegions() != 2 || loop.getBefore().empty() ||
      loop.getAfter().empty())
    return std::nullopt;
  Block &before = loop.getBefore().front();
  Block &after = loop.getAfter().front();
  unsigned lanes = loop->getNumOperands();
  if (lanes == 0 || loop->getNumResults() != lanes ||
      before.getNumArguments() != lanes || after.getNumArguments() != lanes)
    return std::nullopt;

  Operation *condition = before.getTerminator();
  Operation *yield = after.getTerminator();
  if (!condition || condition->getName().getStringRef() != "scf.condition" ||
      condition->getNumOperands() != lanes + 1 || !yield ||
      yield->getName().getStringRef() != "scf.yield" ||
      yield->getNumOperands() != lanes)
    return std::nullopt;

  std::optional<WhileCoordinate> candidate;
  for (unsigned beforeLane = 0; beforeLane < lanes; ++beforeLane) {
    if (!isCoordinateSeed(loop->getOperand(beforeLane), ctx))
      continue;
    for (unsigned afterLane = 0; afterLane < lanes; ++afterLane) {
      if (!sameValueOrIndexCast(condition->getOperand(afterLane + 1),
                                before.getArgument(beforeLane)) ||
          !isPlusOneUpdate(yield->getOperand(beforeLane),
                           after.getArgument(afterLane)))
        continue;
      if (candidate)
        return std::nullopt;
      candidate = WhileCoordinate{loop.getOperation(), beforeLane, afterLane};
    }
  }
  return candidate;
}

// A recovered stage may contain a CUDA scheduling loop, a permuted
// multi-carried data loop (gpJSON/cuJSON), or a data sweep nested inside a
// convergence loop (BitGen). Record every structurally proven +1 recurrence;
// they all denote the stage's canonical per-item coordinate. A -1 lookback
// and state-only fixpoint loops do not match.
static void selectStructuredDataCoordinates(Operation *root,
                                            GenericRaisingContext &ctx) {
  ctx.logicalWhileCoordinates.clear();
  root->walk([&](scf::WhileOp loop) {
    if (std::optional<WhileCoordinate> coordinate =
            findUniqueDataCoordinate(loop, ctx))
      ctx.logicalWhileCoordinates.push_back(*coordinate);
  });
}

static Value selectedPrimaryCoordinate(GenericRaisingContext &ctx) {
  Operation *loop = ctx.logicalLoop;
  if (!loop)
    return {};
  if (auto forLoop = dyn_cast<affine::AffineForOp>(loop))
    return forLoop.getInductionVar();
  if (auto parallel = dyn_cast<affine::AffineParallelOp>(loop))
    return parallel.getIVs().size() == 1 ? parallel.getIVs().front() : Value();
  if (auto forLoop = dyn_cast<scf::ForOp>(loop))
    return forLoop.getInductionVar();
  if (auto parallel = dyn_cast<scf::ParallelOp>(loop))
    return parallel.getInductionVars().size() == 1
               ? parallel.getInductionVars().front()
               : Value();
  return {};
}

static bool isSelectedPrimaryCoordinate(Value value,
                                        GenericRaisingContext &ctx) {
  value = resolveAlias(value, ctx);
  if (!value)
    return false;

  Value stripped = stripIndexAndIntegerCasts(value);
  for (const WhileCoordinate &coordinate : ctx.logicalWhileCoordinates) {
    auto whileLoop = dyn_cast_or_null<scf::WhileOp>(coordinate.loop);
    if (!whileLoop || coordinate.beforeLane >= whileLoop->getNumOperands() ||
        coordinate.afterLane >= whileLoop->getNumResults() ||
        coordinate.beforeLane >=
            whileLoop.getBefore().front().getNumArguments() ||
        coordinate.afterLane >= whileLoop.getAfter().front().getNumArguments())
      continue;
    if (sameValueOrIndexCast(stripped,
                             whileLoop->getOperand(coordinate.beforeLane)) ||
        sameValueOrIndexCast(stripped,
                             whileLoop->getResult(coordinate.afterLane)) ||
        sameValueOrIndexCast(
            stripped,
            whileLoop.getBefore().front().getArgument(coordinate.beforeLane)) ||
        sameValueOrIndexCast(stripped, whileLoop.getAfter().front().getArgument(
                                           coordinate.afterLane)))
      return true;
  }
  value = stripped;

  // Once a data recurrence is known, the outer CUDA/grid-stride IV is only a
  // scheduling coordinate and must not be conflated with the per-item index.
  if (!ctx.logicalWhileCoordinates.empty() || !ctx.logicalLoop)
    return false;

  if (ctx.topLevelFor && isGridStrideCanonicalIndex(value, ctx.topLevelFor))
    return true;

  Value primary = selectedPrimaryCoordinate(ctx);
  return primary && sameValueOrIndexCast(value, primary);
}

static void markUnboundedIteration(AccessAction &record) {
  record.hasUnboundedIteration = true;
}

static void setIndexSymbolAttrs(AccessAction &record, StringRef prefix,
                                StringRef symbol) {
  record.attrs[attrKey(prefix, "_kind")] = "symbol";
  record.attrs[attrKey(prefix, "_symbol")] = symbol.str();
}

static void setLogicalIndexAttrs(AccessAction &record, StringRef prefix) {
  record.attrs[attrKey(prefix, "_kind")] = "logical";
}

static void setGpuIndexAttrs(AccessAction &record, StringRef prefix,
                             StringRef source) {
  record.attrs[attrKey(prefix, "_kind")] = "gpu";
  record.attrs[attrKey(prefix, "_gpu")] = source.str();
  record.attrs[attrKey(prefix, "_dim")] = "x";
}

static void setParameterIndexAttrs(AccessAction &record, StringRef prefix,
                                   int64_t sourceArg) {
  record.attrs[attrKey(prefix, "_kind")] = "parameter";
  record.attrs[attrKey(prefix, "_source_arg")] = std::to_string(sourceArg);
}

static void setLocalIndexAttrs(AccessAction &record, StringRef prefix,
                               int64_t localId) {
  record.attrs[attrKey(prefix, "_kind")] = "local";
  record.attrs[attrKey(prefix, "_local_id")] = std::to_string(localId);
}

static void setIndexConstAttrs(AccessAction &record, StringRef prefix,
                               int64_t value) {
  record.attrs[attrKey(prefix, "_kind")] = "const";
  record.attrs[attrKey(prefix, "_value")] = std::to_string(value);
}

static void setIndexBinaryAttrs(AccessAction &record, StringRef prefix,
                                StringRef opcode) {
  record.attrs[attrKey(prefix, "_kind")] = "binary";
  record.attrs[attrKey(prefix, "_opcode")] = opcode.str();
}

static void fillIndexAttrsFromValue(AccessAction &record, StringRef prefix,
                                    Value value, GenericRaisingContext &ctx);

static void fillBinaryIndexAttrs(AccessAction &record, StringRef prefix,
                                 StringRef opcode, Value lhs, Value rhs,
                                 GenericRaisingContext &ctx) {
  setIndexBinaryAttrs(record, prefix, opcode);
  fillIndexAttrsFromValue(record, attrKey(prefix, "_lhs"), lhs, ctx);
  fillIndexAttrsFromValue(record, attrKey(prefix, "_rhs"), rhs, ctx);
}

static void fillIndexAttrsFromValue(AccessAction &record, StringRef prefix,
                                    Value value, GenericRaisingContext &ctx) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  if (!value) {
    setIndexSymbolAttrs(record, prefix, "unknown");
    return;
  }

  if (isSelectedPrimaryCoordinate(value, ctx)) {
    setLogicalIndexAttrs(record, prefix);
    record.attrs["index_source"] = "polygeist_primary_loop_coordinate";
    return;
  }
  if (ctx.logicalWhileCoordinates.empty() && !ctx.logicalLoop &&
      isCudaGlobalThreadIndex(value, ctx)) {
    setLogicalIndexAttrs(record, prefix);
    record.attrs["index_source"] = "polygeist_cuda_global_thread_index";
    return;
  }
  for (StringRef source : {StringRef("blockIdx"), StringRef("blockDim"),
                           StringRef("threadIdx"), StringRef("gridDim")}) {
    if (!isPolygeistGpuGlobalLoad(value, source))
      continue;
    StringRef gpuSource = source == "blockIdx"    ? StringRef("block_id")
                          : source == "blockDim"  ? StringRef("block_dim")
                          : source == "threadIdx" ? StringRef("thread_id")
                                                  : StringRef("grid_dim");
    setGpuIndexAttrs(record, prefix, gpuSource);
    return;
  }
  if (auto constant = integerConstant(value))
    return setIndexConstAttrs(record, prefix, *constant);

  if (auto add = value.getDefiningOp<arith::AddIOp>())
    return fillBinaryIndexAttrs(record, prefix, "+", add.getLhs(), add.getRhs(),
                                ctx);
  if (auto sub = value.getDefiningOp<arith::SubIOp>())
    return fillBinaryIndexAttrs(record, prefix, "-", sub.getLhs(), sub.getRhs(),
                                ctx);
  if (auto mul = value.getDefiningOp<arith::MulIOp>())
    return fillBinaryIndexAttrs(record, prefix, "*", mul.getLhs(), mul.getRhs(),
                                ctx);
  if (auto div = value.getDefiningOp<arith::DivSIOp>())
    return fillBinaryIndexAttrs(record, prefix, "sdiv", div.getLhs(),
                                div.getRhs(), ctx);
  if (auto div = value.getDefiningOp<arith::DivUIOp>())
    return fillBinaryIndexAttrs(record, prefix, "udiv", div.getLhs(),
                                div.getRhs(), ctx);
  if (auto rem = value.getDefiningOp<arith::RemSIOp>())
    return fillBinaryIndexAttrs(record, prefix, "srem", rem.getLhs(),
                                rem.getRhs(), ctx);
  if (auto rem = value.getDefiningOp<arith::RemUIOp>())
    return fillBinaryIndexAttrs(record, prefix, "urem", rem.getLhs(),
                                rem.getRhs(), ctx);

  if (auto arg = dyn_cast<BlockArgument>(value)) {
    if (ctx.rootDriver && arg.getOwner() == &ctx.rootDriver.front()) {
      setParameterIndexAttrs(record, prefix, arg.getArgNumber());
      return;
    }
    setLocalIndexAttrs(record, prefix, getOrCreateStageLocalId(ctx, value));
    return;
  }

  setLocalIndexAttrs(record, prefix, getOrCreateStageLocalId(ctx, value));
}

static std::string affineExprName(AffineExpr expr, ValueRange operands,
                                  GenericRaisingContext &ctx);

static void fillIndexAttrsFromAffineExpr(AccessAction &record, StringRef prefix,
                                         AffineExpr expr, ValueRange operands,
                                         GenericRaisingContext &ctx) {
  if (auto dim = expr.dyn_cast<AffineDimExpr>()) {
    unsigned pos = dim.getPosition();
    if (pos < operands.size())
      return fillIndexAttrsFromValue(record, prefix, operands[pos], ctx);
  }
  if (auto sym = expr.dyn_cast<AffineSymbolExpr>()) {
    unsigned pos = sym.getPosition();
    if (pos < operands.size())
      return fillIndexAttrsFromValue(record, prefix, operands[pos], ctx);
  }
  if (auto constant = expr.dyn_cast<AffineConstantExpr>())
    return setIndexConstAttrs(record, prefix, constant.getValue());
  if (auto binary = expr.dyn_cast<AffineBinaryOpExpr>()) {
    StringRef opcode = "?";
    switch (binary.getKind()) {
    case AffineExprKind::Add:
      opcode = "+";
      break;
    case AffineExprKind::Mul:
      opcode = "*";
      break;
    case AffineExprKind::Mod:
      opcode = "srem";
      break;
    case AffineExprKind::FloorDiv:
      opcode = "sdiv";
      break;
    case AffineExprKind::CeilDiv:
      opcode = "ceildiv";
      break;
    default:
      break;
    }
    setIndexBinaryAttrs(record, prefix, opcode);
    fillIndexAttrsFromAffineExpr(record, attrKey(prefix, "_lhs"),
                                 binary.getLHS(), operands, ctx);
    fillIndexAttrsFromAffineExpr(record, attrKey(prefix, "_rhs"),
                                 binary.getRHS(), operands, ctx);
    return;
  }
  setIndexSymbolAttrs(record, prefix, "affine_unknown");
}

static std::string affineExprName(AffineExpr expr, ValueRange operands,
                                  GenericRaisingContext &ctx) {
  if (auto dim = expr.dyn_cast<AffineDimExpr>()) {
    unsigned pos = dim.getPosition();
    if (pos < operands.size())
      if (isSelectedPrimaryCoordinate(operands[pos], ctx) ||
          (ctx.logicalWhileCoordinates.empty() && !ctx.logicalLoop &&
           isCudaGlobalThreadIndex(operands[pos], ctx)))
        return "logical";
    if (pos < operands.size())
      return getOrCreateValueName(ctx, resolveAlias(operands[pos], ctx));
  }
  if (auto sym = expr.dyn_cast<AffineSymbolExpr>()) {
    unsigned pos = sym.getPosition();
    if (pos < operands.size())
      if (isSelectedPrimaryCoordinate(operands[pos], ctx) ||
          (ctx.logicalWhileCoordinates.empty() && !ctx.logicalLoop &&
           isCudaGlobalThreadIndex(operands[pos], ctx)))
        return "logical";
    if (pos < operands.size())
      return getOrCreateValueName(ctx, resolveAlias(operands[pos], ctx));
  }
  if (auto constant = expr.dyn_cast<AffineConstantExpr>())
    return std::to_string(constant.getValue());
  if (auto binary = expr.dyn_cast<AffineBinaryOpExpr>()) {
    StringRef opcode = "?";
    switch (binary.getKind()) {
    case AffineExprKind::Add:
      opcode = "+";
      break;
    case AffineExprKind::Mul:
      opcode = "*";
      break;
    case AffineExprKind::Mod:
      opcode = "%";
      break;
    case AffineExprKind::FloorDiv:
    case AffineExprKind::CeilDiv:
      opcode = "/";
      break;
    default:
      break;
    }
    return (Twine(affineExprName(binary.getLHS(), operands, ctx)) + opcode +
            affineExprName(binary.getRHS(), operands, ctx))
        .str();
  }
  return "affine_unknown";
}

static bool isZeroConstant(Value value) {
  auto constant = integerConstant(value);
  return constant && *constant == 0;
}

static std::string indexTermsName(ArrayRef<Value> terms,
                                  GenericRaisingContext &ctx) {
  if (terms.empty())
    return "0";
  std::string result;
  for (Value term : terms) {
    if (!result.empty())
      result += "+";
    term = resolveAlias(term, ctx);
    if (isSelectedPrimaryCoordinate(term, ctx)) {
      result += "logical";
      continue;
    }
    if (ctx.logicalWhileCoordinates.empty() && !ctx.logicalLoop &&
        isCudaGlobalThreadIndex(term, ctx)) {
      result += "logical";
      continue;
    }
    if (auto arg = dyn_cast_or_null<BlockArgument>(term)) {
      result += "local" + std::to_string(getOrCreateStageLocalId(ctx, term));
      continue;
    }
    result += getOrCreateValueName(ctx, term);
  }
  return result;
}

static void fillIndexAttrsFromTerms(AccessAction &record, StringRef prefix,
                                    ArrayRef<Value> terms,
                                    GenericRaisingContext &ctx) {
  if (terms.empty())
    return setIndexConstAttrs(record, prefix, 0);
  if (terms.size() == 1)
    return fillIndexAttrsFromValue(record, prefix, terms.front(), ctx);

  setIndexBinaryAttrs(record, prefix, "+");
  fillIndexAttrsFromTerms(record, attrKey(prefix, "_lhs"), terms.drop_back(),
                          ctx);
  fillIndexAttrsFromValue(record, attrKey(prefix, "_rhs"), terms.back(), ctx);
}

static int64_t bytesForElementType(Type type) {
  if (auto intType = dyn_cast<IntegerType>(type))
    return std::max<int64_t>(1, (intType.getWidth() + 7) / 8);
  if (type.isF16())
    return 2;
  if (type.isF32())
    return 4;
  if (type.isF64())
    return 8;
  return 4;
}

static int64_t bytesForMemRef(Value memref) {
  auto type = dyn_cast<MemRefType>(memref.getType());
  if (!type)
    return 4;
  return bytesForElementType(type.getElementType());
}

static int64_t bytesForStoredValue(Value stored, Value memref) {
  if (!stored)
    return bytesForMemRef(memref);
  int64_t valueBytes = bytesForElementType(stored.getType());
  if (valueBytes > 0)
    return valueBytes;
  return bytesForMemRef(memref);
}

static int64_t accessBytesForAffineLoad(affine::AffineLoadOp load) {
  return bytesForMemRef(load.getMemref());
}

static int64_t accessBytesForAffineStore(affine::AffineStoreOp store) {
  return bytesForStoredValue(store.getValueToStore(), store.getMemref());
}

static bool hasUnitOrBoolAttr(Operation *op, StringRef name) {
  if (auto boolAttr = op->getAttrOfType<BoolAttr>(name))
    return boolAttr.getValue();
  if (op->hasAttr(name))
    return true;
  return false;
}

static Value traceMemRef(Value value, GenericRaisingContext *ctx = nullptr) {
  while (value) {
    if (ctx)
      value = resolveAlias(value, *ctx);
    Operation *def = value.getDefiningOp();
    if (!def)
      return value;
    StringRef opName = def->getName().getStringRef();
    if (opName == "polygeist.pointer2memref" && def->getNumOperands() == 1) {
      value = def->getOperand(0);
      continue;
    }
    if (auto cast = dyn_cast<memref::CastOp>(def)) {
      value = cast.getSource();
      continue;
    }
    if (opName == "polygeist.memref2pointer" && def->getNumOperands() == 1) {
      value = def->getOperand(0);
      continue;
    }
    return value;
  }
  return {};
}

static bool isCudaIndexGlobalMemRef(Value memref,
                                    GenericRaisingContext *ctx = nullptr) {
  memref = traceMemRef(memref, ctx);
  auto getGlobal =
      memref ? memref.getDefiningOp<memref::GetGlobalOp>() : nullptr;
  return getGlobal && isCudaIndexGlobalName(getGlobal.getName());
}

static Value traceMemRefRootAndOffsets(Value value,
                                       SmallVectorImpl<Value> &offsets,
                                       GenericRaisingContext *ctx = nullptr) {
  llvm::SmallPtrSet<Value, 8> seen;
  while (value) {
    if (ctx)
      value = resolveAlias(value, *ctx);
    if (!seen.insert(value).second)
      return value;

    Operation *def = value.getDefiningOp();
    if (!def)
      return value;

    if (auto cast = dyn_cast<memref::CastOp>(def)) {
      value = cast.getSource();
      continue;
    }

    StringRef opName = def->getName().getStringRef();
    if (opName == "polygeist.pointer2memref" && def->getNumOperands() == 1) {
      value = def->getOperand(0);
      continue;
    }
    if (opName == "polygeist.subindex" && def->getNumOperands() >= 2) {
      offsets.push_back(def->getOperand(1));
      value = def->getOperand(0);
      continue;
    }

    if (opName == "polygeist.memref2pointer" && def->getNumOperands() == 1) {
      value = def->getOperand(0);
      continue;
    }

    return value;
  }
  return {};
}

static bool isMemRefSlot(Value memref, GenericRaisingContext *ctx = nullptr) {
  memref = traceMemRef(memref, ctx);
  auto type = memref ? dyn_cast<MemRefType>(memref.getType()) : MemRefType();
  return type && isa<MemRefType>(type.getElementType());
}

static bool rememberMemRefSlotStore(affine::AffineStoreOp store,
                                    GenericRaisingContext &ctx) {
  if (!isMemRefSlot(store.getMemref(), &ctx))
    return false;
  Value stored = resolveAlias(store.getValueToStore(), ctx);
  if (!isa<MemRefType>(stored.getType()))
    return false;
  Value slot = traceMemRef(store.getMemref(), &ctx);
  ctx.memrefSlotAliases[slot] = stored;
  return true;
}

static bool rememberMemRefSlotLoad(affine::AffineLoadOp load,
                                   GenericRaisingContext &ctx) {
  if (!isMemRefSlot(load.getMemref(), &ctx))
    return false;
  Value slot = traceMemRef(load.getMemref(), &ctx);
  auto it = ctx.memrefSlotAliases.find(slot);
  if (it != ctx.memrefSlotAliases.end() && it->second)
    ctx.valueAliases[load.getResult()] = it->second;
  return true;
}

static std::string bufferName(Value memref,
                              llvm::DenseMap<Value, std::string> &names,
                              GenericRaisingContext *ctx = nullptr) {
  memref = traceMemRef(memref, ctx);
  if (!memref)
    return "";
  auto it = names.find(memref);
  if (it != names.end())
    return it->second;
  if (auto arg = dyn_cast<BlockArgument>(memref)) {
    std::string name = ("arg" + Twine(arg.getArgNumber())).str();
    names[memref] = name;
    return name;
  }
  std::string name = ("buf" + Twine(names.size())).str();
  names[memref] = name;
  return name;
}

static std::string
affineAccessBufferName(Operation *op, Value memref,
                       llvm::DenseMap<Value, std::string> &names,
                       GenericRaisingContext *ctx = nullptr) {
  if (auto attr = op->getAttrOfType<StringAttr>("bitstream.buffer"))
    return sanitize(attr.getValue());
  if (auto attr = op->getAttrOfType<StringAttr>("buffer"))
    return sanitize(attr.getValue());
  return bufferName(memref, names, ctx);
}

static bool isFunctionArgument(Value value, unsigned argNumber,
                               GenericRaisingContext &ctx) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  auto arg = dyn_cast_or_null<BlockArgument>(value);
  if (!arg)
    return false;
  return arg.getArgNumber() == argNumber &&
         isa_and_nonnull<func::FuncOp>(arg.getOwner()->getParentOp());
}

static void flattenAddTerms(Value value, SmallVectorImpl<Value> &terms,
                            GenericRaisingContext &ctx) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  if (!value)
    return;
  if (auto add = value.getDefiningOp<arith::AddIOp>()) {
    flattenAddTerms(add.getLhs(), terms, ctx);
    flattenAddTerms(add.getRhs(), terms, ctx);
    return;
  }
  terms.push_back(value);
}

static bool matchLinearizedStreamTerm(Value value, GenericRaisingContext &ctx,
                                      int64_t &streamId) {
  value = stripIndexAndIntegerCasts(resolveAlias(value, ctx));
  if (!value)
    return false;

  if (isFunctionArgument(value, /*argNumber=*/1, ctx)) {
    streamId = 1;
    return true;
  }

  auto mul = value.getDefiningOp<arith::MulIOp>();
  if (!mul)
    return false;

  if (isFunctionArgument(mul.getLhs(), /*argNumber=*/1, ctx)) {
    if (auto rhs = integerConstant(mul.getRhs())) {
      streamId = *rhs;
      return true;
    }
  }
  if (isFunctionArgument(mul.getRhs(), /*argNumber=*/1, ctx)) {
    if (auto lhs = integerConstant(mul.getLhs())) {
      streamId = *lhs;
      return true;
    }
  }
  return false;
}

static void normalizeLinearizedBitGenStream(std::string &buffer,
                                            SmallVectorImpl<Value> &indexTerms,
                                            GenericRaisingContext &ctx) {
  // BitGen's generated kernels linearize temporary bitstreams as:
  //   tmp_streams[stream_id * n_unit_basic + element_index]
  // where Polygeist names tmp_streams as arg5 and n_unit_basic as arg1.
  // Split the flat temp array into logical stream buffers so RAW analysis
  // compares producer/consumer uses per stream instead of conflating all
  // generated regex temporaries into one irregular buffer.
  bool isTmpStreamBuffer = buffer == "arg4" || buffer == "arg5" ||
                           StringRef(buffer).contains("tmp_stream");
  if (!ctx.enableBitGenLinearizedStreams || !isTmpStreamBuffer)
    return;

  SmallVector<Value> flatTerms;
  for (Value term : indexTerms)
    flattenAddTerms(term, flatTerms, ctx);

  int64_t streamId = 0;
  SmallVector<Value> elementTerms;
  for (Value term : flatTerms) {
    int64_t matchedStream = 0;
    if (matchLinearizedStreamTerm(term, ctx, matchedStream)) {
      streamId += matchedStream;
      continue;
    }
    elementTerms.push_back(term);
  }

  buffer = (Twine(buffer) + "_stream" + Twine(streamId)).str();
  indexTerms.clear();
  indexTerms.append(elementTerms.begin(), elementTerms.end());
}

static bool tracePointer(Value pointer, Value &memref, Value &index,
                         GenericRaisingContext *ctx = nullptr) {
  if (ctx)
    pointer = resolveAlias(pointer, *ctx);
  Operation *def = pointer.getDefiningOp();
  if (!def)
    return false;

  StringRef opName = def->getName().getStringRef();
  if (opName == "polygeist.memref2pointer" && def->getNumOperands() == 1) {
    memref = traceMemRef(def->getOperand(0), ctx);
    return static_cast<bool>(memref);
  }

  if (opName == "llvm.getelementptr" && def->getNumOperands() >= 2) {
    if (!index)
      index = def->getOperand(def->getNumOperands() - 1);
    return tracePointer(def->getOperand(0), memref, index, ctx);
  }

  return false;
}

static bool loadHasOnlyLowBitProjection(Value loaded) {
  bool sawProjection = false;
  for (Operation *user : loaded.getUsers()) {
    auto andOp = dyn_cast<arith::AndIOp>(user);
    if (!andOp)
      return false;
    bool lowBit = (andOp.getLhs() == loaded && isOneConstant(andOp.getRhs())) ||
                  (andOp.getRhs() == loaded && isOneConstant(andOp.getLhs()));
    if (!lowBit)
      return false;
    sawProjection = true;
  }
  return sawProjection;
}

static bool isBitwiseNotOf(arith::XOrIOp xori, Value value) {
  return (xori.getLhs() == value && isAllOnesConstant(xori.getRhs())) ||
         (xori.getRhs() == value && isAllOnesConstant(xori.getLhs()));
}

static bool isCtlzLikeOp(Operation *op) {
  return op && op->getName().getStringRef() == "math.ctlz" &&
         op->getNumResults() == 1;
}

static bool isLowBitAndUser(Operation *user, Value value) {
  auto andOp = dyn_cast<arith::AndIOp>(user);
  if (!andOp)
    return false;
  return (andOp.getLhs() == value && isOneConstant(andOp.getRhs())) ||
         (andOp.getRhs() == value && isOneConstant(andOp.getLhs()));
}

static bool isIntegerCastUser(Operation *user) {
  return isa<arith::ExtSIOp, arith::ExtUIOp, arith::TruncIOp,
             arith::IndexCastOp, arith::IndexCastUIOp>(user);
}

static Value singleResult(Operation *op) {
  return op && op->getNumResults() == 1 ? op->getResult(0) : Value();
}

static bool isConstantCompareUser(Operation *user, Value value) {
  auto cmp = dyn_cast<arith::CmpIOp>(user);
  if (!cmp)
    return false;
  return (cmp.getLhs() == value && integerConstant(cmp.getRhs())) ||
         (cmp.getRhs() == value && integerConstant(cmp.getLhs()));
}

static bool valueFeedsLowBitProjection(Value value,
                                       llvm::SmallPtrSetImpl<Value> &visited,
                                       unsigned depth = 0) {
  if (!value || depth > 8 || !visited.insert(value).second)
    return false;

  for (Operation *user : value.getUsers()) {
    if (isLowBitAndUser(user, value))
      return true;
    if (isConstantCompareUser(user, value))
      return true;

    if (isIntegerCastUser(user)) {
      if (valueFeedsLowBitProjection(singleResult(user), visited, depth + 1))
        return true;
      continue;
    }

    if (auto xori = dyn_cast<arith::XOrIOp>(user)) {
      if (isBitwiseNotOf(xori, value) &&
          valueFeedsLowBitProjection(xori.getResult(), visited, depth + 1))
        return true;
      continue;
    }

    if (isCtlzLikeOp(user)) {
      if (valueFeedsLowBitProjection(user->getResult(0), visited, depth + 1))
        return true;
      continue;
    }

    if (auto yield = dyn_cast<scf::YieldOp>(user)) {
      Operation *parent = yield->getParentOp();
      if (!parent)
        continue;
      for (auto [operandIndex, operand] :
           llvm::enumerate(yield.getOperands())) {
        if (operand != value)
          continue;
        if (operandIndex < parent->getNumResults() &&
            valueFeedsLowBitProjection(parent->getResult(operandIndex), visited,
                                       depth + 1))
          return true;
      }
      continue;
    }
  }
  return false;
}

static bool loadFeedsOnlyProjectionSafeOps(Value value,
                                           llvm::SmallPtrSetImpl<Value> &seen,
                                           unsigned depth = 0) {
  if (!value || depth > 8 || !seen.insert(value).second)
    return true;

  for (Operation *user : value.getUsers()) {
    if (isLowBitAndUser(user, value))
      continue;

    if (isa<arith::CmpIOp>(user))
      continue;

    if (isIntegerCastUser(user)) {
      if (!loadFeedsOnlyProjectionSafeOps(singleResult(user), seen, depth + 1))
        return false;
      continue;
    }

    if (auto xori = dyn_cast<arith::XOrIOp>(user)) {
      if (!isBitwiseNotOf(xori, value) ||
          !loadFeedsOnlyProjectionSafeOps(xori.getResult(), seen, depth + 1))
        return false;
      continue;
    }

    if (isCtlzLikeOp(user)) {
      if (!loadFeedsOnlyProjectionSafeOps(user->getResult(0), seen, depth + 1))
        return false;
      continue;
    }

    if (auto yield = dyn_cast<scf::YieldOp>(user)) {
      Operation *parent = yield->getParentOp();
      if (!parent)
        return false;
      for (auto [operandIndex, operand] :
           llvm::enumerate(yield.getOperands())) {
        if (operand != value)
          continue;
        if (operandIndex >= parent->getNumResults() ||
            !loadFeedsOnlyProjectionSafeOps(parent->getResult(operandIndex),
                                            seen, depth + 1))
          return false;
      }
      continue;
    }

    return false;
  }
  return true;
}

static bool loadHasOnlyFiniteStateProjection(Value loaded,
                                             StringRef &projectionKind) {
  if (loadHasOnlyLowBitProjection(loaded)) {
    projectionKind = "ssa_low_bit";
    return true;
  }

  llvm::SmallPtrSet<Value, 16> projectionVisited;
  if (!valueFeedsLowBitProjection(loaded, projectionVisited))
    return false;

  llvm::SmallPtrSet<Value, 16> safetyVisited;
  if (!loadFeedsOnlyProjectionSafeOps(loaded, safetyVisited))
    return false;

  projectionKind = "ssa_not_ctlz_low_bit";
  return true;
}

static std::optional<int64_t> combineFiniteDomains(std::optional<int64_t> lhs,
                                                   std::optional<int64_t> rhs) {
  if (!lhs || !rhs)
    return std::nullopt;
  return std::max<int64_t>(*lhs, *rhs);
}

static std::optional<int64_t>
finiteValueDomain(Value value, llvm::SmallPtrSetImpl<Value> &seen,
                  unsigned depth = 0,
                  llvm::SmallPtrSetImpl<Value> *assumedBinary = nullptr) {
  value = stripIndexAndIntegerCasts(value);
  if (!value || depth > 10 || !seen.insert(value).second)
    return std::nullopt;

  if (assumedBinary && assumedBinary->contains(value))
    return 2;

  if (value.getType().isInteger(1))
    return 2;

  if (auto constant = integerConstant(value)) {
    if (*constant == 0)
      return 1;
    if (*constant == 1)
      return 2;
  }

  if (auto cmp = value.getDefiningOp<arith::CmpIOp>())
    return 2;

  if (auto andOp = value.getDefiningOp<arith::AndIOp>()) {
    if (isOneConstant(andOp.getLhs()) || isOneConstant(andOp.getRhs()))
      return 2;
  }

  if (auto xori = value.getDefiningOp<arith::XOrIOp>()) {
    if (isOneConstant(xori.getLhs()))
      return finiteValueDomain(xori.getRhs(), seen, depth + 1, assumedBinary);
    if (isOneConstant(xori.getRhs()))
      return finiteValueDomain(xori.getLhs(), seen, depth + 1, assumedBinary);
  }

  if (auto select = value.getDefiningOp<arith::SelectOp>()) {
    llvm::SmallPtrSet<Value, 16> trueSeen(seen.begin(), seen.end());
    llvm::SmallPtrSet<Value, 16> falseSeen(seen.begin(), seen.end());
    return combineFiniteDomains(
        finiteValueDomain(select.getTrueValue(), trueSeen, depth + 1,
                          assumedBinary),
        finiteValueDomain(select.getFalseValue(), falseSeen, depth + 1,
                          assumedBinary));
  }

  if (auto ifOp = value.getDefiningOp<scf::IfOp>()) {
    auto result = dyn_cast<OpResult>(value);
    if (!result)
      return std::nullopt;
    unsigned resultNo = result.getResultNumber();
    Operation *thenTerm = ifOp.getThenRegion().front().getTerminator();
    Operation *elseTerm = ifOp.getElseRegion().empty()
                              ? nullptr
                              : ifOp.getElseRegion().front().getTerminator();
    if (!thenTerm || !elseTerm || !isa<scf::YieldOp>(thenTerm) ||
        !isa<scf::YieldOp>(elseTerm) ||
        thenTerm->getNumOperands() <= resultNo ||
        elseTerm->getNumOperands() <= resultNo)
      return std::nullopt;
    llvm::SmallPtrSet<Value, 16> thenSeen(seen.begin(), seen.end());
    llvm::SmallPtrSet<Value, 16> elseSeen(seen.begin(), seen.end());
    return combineFiniteDomains(
        finiteValueDomain(thenTerm->getOperand(resultNo), thenSeen, depth + 1,
                          assumedBinary),
        finiteValueDomain(elseTerm->getOperand(resultNo), elseSeen, depth + 1,
                          assumedBinary));
  }

  Operation *def = value.getDefiningOp();
  auto result = dyn_cast<OpResult>(value);
  if (def && result && def->getName().getStringRef() == "scf.while" &&
      def->getNumRegions() >= 2) {
    unsigned resultNo = result.getResultNumber();
    Region &before = def->getRegion(0);
    Region &after = def->getRegion(1);
    if (before.empty() || after.empty())
      return std::nullopt;
    Operation *condition = before.front().getTerminator();
    Operation *afterYield = after.front().getTerminator();
    if (!condition || !afterYield ||
        condition->getName().getStringRef() != "scf.condition" ||
        afterYield->getName().getStringRef() != "scf.yield" ||
        condition->getNumOperands() <= resultNo)
      return std::nullopt;

    unsigned conditionArgBase =
        condition->getNumOperands() == def->getNumResults() + 1 ? 1 : 0;
    if (condition->getNumOperands() <= resultNo + conditionArgBase)
      return std::nullopt;
    Value carried = condition->getOperand(resultNo + conditionArgBase);
    auto carriedArg = dyn_cast<BlockArgument>(carried);
    if (!carriedArg)
      return std::nullopt;
    unsigned carriedArgNo = carriedArg.getArgNumber();
    if (def->getNumOperands() <= carriedArgNo ||
        afterYield->getNumOperands() <= carriedArgNo)
      return std::nullopt;

    llvm::SmallPtrSet<Value, 4> localAssumptions;
    if (after.front().getNumArguments() > resultNo)
      localAssumptions.insert(after.front().getArgument(resultNo));
    llvm::SmallPtrSet<Value, 16> initSeen(seen.begin(), seen.end());
    llvm::SmallPtrSet<Value, 16> updateSeen(seen.begin(), seen.end());
    return combineFiniteDomains(
        finiteValueDomain(def->getOperand(carriedArgNo), initSeen, depth + 1,
                          assumedBinary),
        finiteValueDomain(afterYield->getOperand(carriedArgNo), updateSeen,
                          depth + 1, &localAssumptions));
  }

  return std::nullopt;
}

static std::optional<int64_t> finiteValueDomain(Value value) {
  llvm::SmallPtrSet<Value, 16> seen;
  return finiteValueDomain(value, seen);
}

static void copyMlirAffineDependenceAttrs(AccessAction &record,
                                          Operation *sourceOp) {
  if (!sourceOp)
    return;
  if (auto attr = sourceOp->getAttrOfType<StringAttr>(
          "bitstream.mlir_affine_dependence"))
    record.attrs["mlir_affine_dependence"] = attr.getValue().str();
  if (sourceOp->hasAttr("bitstream.mlir_affine_dependence_proven"))
    record.attrs["mlir_affine_dependence_proven"] = "true";
  if (sourceOp->hasAttr("bitstream.mlir_affine_no_dependence"))
    record.attrs["mlir_affine_no_dependence"] = "true";
  if (sourceOp->hasAttr("bitstream.mlir_affine_dependence_failed"))
    record.attrs["mlir_affine_dependence_failed"] = "true";
}

static void addGenericAccess(AccessStage &stage, llvm::StringSet<> &seen,
                             StringRef kind, StringRef buffer, Value index,
                             int64_t bytes, StringRef meaning,
                             GenericRaisingContext &ctx,
                             bool noExactReadEscapes = false,
                             std::optional<int64_t> valueDomain = std::nullopt,
                             Operation *sourceOp = nullptr) {
  if (buffer.empty() || !index)
    return;
  AccessAction record = action({{"kind", kind.str()},
                                {"buffer", buffer.str()},
                                {"index", getOrCreateValueName(ctx, index)},
                                {"bytes", std::to_string(bytes)},
                                {"meaning", meaning.str()}});
  fillIndexAttrsFromValue(record, "index", index, ctx);
  (void)noExactReadEscapes;
  if (Value seed = dataDependentBackwardWalkSeed(index)) {
    markUnboundedIteration(record);
    fillIndexAttrsFromValue(record, "unbounded_seed", seed, ctx);
  }
  if (valueDomain)
    record.attrs["value_domain"] = std::to_string(*valueDomain);
  copyMlirAffineDependenceAttrs(record, sourceOp);
  std::string key = kind.str() + "|" + buffer.str() + "|" +
                    getAttr(record, "index") + "|" + std::to_string(bytes);
  if (seen.contains(key))
    return;
  seen.insert(key);
  stage.actions.push_back(std::move(record));
}

static void
addGenericAffineAccess(AccessStage &stage, llvm::StringSet<> &seen,
                       StringRef kind, StringRef buffer, AffineMap map,
                       ValueRange operands, int64_t bytes, StringRef meaning,
                       GenericRaisingContext &ctx,
                       bool noExactReadEscapes = false,
                       std::optional<int64_t> valueDomain = std::nullopt,
                       Operation *sourceOp = nullptr) {
  if (buffer.empty() || map.getNumResults() == 0)
    return;
  AffineExpr expr = map.getResult(0);
  std::string indexName = affineExprName(expr, operands, ctx);
  AccessAction record = action({{"kind", kind.str()},
                                {"buffer", buffer.str()},
                                {"index", indexName},
                                {"bytes", std::to_string(bytes)},
                                {"meaning", meaning.str()}});
  fillIndexAttrsFromAffineExpr(record, "index", expr, operands, ctx);
  (void)noExactReadEscapes;
  if (valueDomain)
    record.attrs["value_domain"] = std::to_string(*valueDomain);
  copyMlirAffineDependenceAttrs(record, sourceOp);
  std::string key = kind.str() + "|" + buffer.str() + "|" +
                    getAttr(record, "index") + "|" + std::to_string(bytes);
  if (seen.contains(key))
    return;
  seen.insert(key);
  stage.actions.push_back(std::move(record));
}

static void addGenericAccessWithIndexTerms(
    AccessStage &stage, llvm::StringSet<> &seen, StringRef kind,
    StringRef buffer, ArrayRef<Value> indexTerms, int64_t bytes,
    StringRef meaning, GenericRaisingContext &ctx,
    bool noExactReadEscapes = false,
    std::optional<int64_t> valueDomain = std::nullopt,
    Operation *sourceOp = nullptr) {
  if (buffer.empty())
    return;
  AccessAction record = action({{"kind", kind.str()},
                                {"buffer", buffer.str()},
                                {"index", indexTermsName(indexTerms, ctx)},
                                {"bytes", std::to_string(bytes)},
                                {"meaning", meaning.str()}});
  fillIndexAttrsFromTerms(record, "index", indexTerms, ctx);
  (void)noExactReadEscapes;
  if (Value seed = dataDependentBackwardWalkSeed(indexTerms)) {
    markUnboundedIteration(record);
    fillIndexAttrsFromValue(record, "unbounded_seed", seed, ctx);
  }
  if (valueDomain)
    record.attrs["value_domain"] = std::to_string(*valueDomain);
  copyMlirAffineDependenceAttrs(record, sourceOp);
  std::string key = kind.str() + "|" + buffer.str() + "|" +
                    getAttr(record, "index") + "|" + std::to_string(bytes);
  if (seen.contains(key))
    return;
  seen.insert(key);
  stage.actions.push_back(std::move(record));
}

static void addGenericStateProjection(AccessStage &stage,
                                      llvm::StringSet<> &seen, StringRef buffer,
                                      Value index, GenericRaisingContext &ctx,
                                      StringRef projectionKind = StringRef()) {
  AccessAction projection = action({{"kind", "state_projection"},
                                    {"buffer", buffer.str()},
                                    {"index", getOrCreateValueName(ctx, index)},
                                    {"domain", "2"},
                                    {"modulus", "2"}});
  fillIndexAttrsFromValue(projection, "index", index, ctx);
  if (!projectionKind.empty())
    projection.attrs["projection_kind"] = projectionKind.str();
  if (isDataDependentBackwardWalkIndex(index))
    markUnboundedIteration(projection);
  std::string key =
      buffer.str() + "|" + getAttr(projection, "index") + "|domain2";
  if (seen.contains(key))
    return;
  seen.insert(key);
  stage.actions.push_back(std::move(projection));
}

static void addGenericStateProjectionWithIndexTerms(
    AccessStage &stage, llvm::StringSet<> &seen, StringRef buffer,
    ArrayRef<Value> indexTerms, GenericRaisingContext &ctx,
    StringRef projectionKind = StringRef()) {
  AccessAction projection = action({{"kind", "state_projection"},
                                    {"buffer", buffer.str()},
                                    {"index", indexTermsName(indexTerms, ctx)},
                                    {"domain", "2"},
                                    {"modulus", "2"}});
  fillIndexAttrsFromTerms(projection, "index", indexTerms, ctx);
  if (!projectionKind.empty())
    projection.attrs["projection_kind"] = projectionKind.str();
  if (hasDataDependentBackwardWalkIndex(indexTerms))
    markUnboundedIteration(projection);
  std::string key =
      buffer.str() + "|" + getAttr(projection, "index") + "|domain2";
  if (seen.contains(key))
    return;
  seen.insert(key);
  stage.actions.push_back(std::move(projection));
}

static void
addGenericAffineStateProjection(AccessStage &stage, llvm::StringSet<> &seen,
                                StringRef buffer, AffineMap map,
                                ValueRange operands, GenericRaisingContext &ctx,
                                StringRef projectionKind = StringRef()) {
  if (buffer.empty() || map.getNumResults() == 0)
    return;
  AffineExpr expr = map.getResult(0);
  std::string indexName = affineExprName(expr, operands, ctx);
  AccessAction projection = action({{"kind", "state_projection"},
                                    {"buffer", buffer.str()},
                                    {"index", indexName},
                                    {"domain", "2"},
                                    {"modulus", "2"}});
  fillIndexAttrsFromAffineExpr(projection, "index", expr, operands, ctx);
  if (!projectionKind.empty())
    projection.attrs["projection_kind"] = projectionKind.str();
  std::string key =
      buffer.str() + "|" + getAttr(projection, "index") + "|domain2";
  if (seen.contains(key))
    return;
  seen.insert(key);
  stage.actions.push_back(std::move(projection));
}

static bool isBitstreamAdvanceCall(func::CallOp call, StringRef &direction) {
  StringRef callee = call.getCallee();
  if (!callee.contains("BSAdvance"))
    return false;
  if (callee.contains("Right")) {
    direction = "right";
    return true;
  }
  if (callee.contains("Left")) {
    direction = "left";
    return true;
  }
  direction = "unknown";
  return true;
}

static void addGenericAdvance(AccessStage &stage,
                              llvm::StringMap<unsigned> &seenAdvances,
                              func::CallOp call) {
  StringRef direction;
  if (!isBitstreamAdvanceCall(call, direction))
    return;

  int64_t distance = 0;
  if (call.getNumOperands() > 1)
    distance = integerConstant(call.getOperand(1)).value_or(0);

  std::string key =
      (direction + Twine("|") + Twine(distance) + "|" + call.getCallee()).str();
  auto existing = seenAdvances.find(key);
  if (existing != seenAdvances.end()) {
    AccessAction &record = stage.actions[existing->second];
    int64_t count = parseInteger(getAttr(record, "count")).value_or(1);
    record.attrs["count"] = std::to_string(count + 1);
    return;
  }

  AccessAction record = action({{"kind", "advance"},
                                {"direction", direction.str()},
                                {"distance", std::to_string(distance)},
                                {"count", "1"},
                                {"callee", call.getCallee().str()}});
  if (call.getCallee().contains("Sync"))
    record.attrs["sync"] = "true";
  seenAdvances[key] = stage.actions.size();
  stage.actions.push_back(std::move(record));
}

static bool affineMapIsConstantZero(AffineMap map) {
  if (map.getNumResults() != 1)
    return false;
  auto constant = map.getResult(0).dyn_cast<AffineConstantExpr>();
  return constant && constant.getValue() == 0;
}

static void collectGenericAliasFacts(Operation *root,
                                     GenericRaisingContext &ctx) {
  root->walk([&](Operation *op) {
    if (auto store = dyn_cast<affine::AffineStoreOp>(op)) {
      rememberMemRefSlotStore(store, ctx);
      return;
    }
    if (auto load = dyn_cast<affine::AffineLoadOp>(op)) {
      rememberMemRefSlotLoad(load, ctx);
      return;
    }
    if (auto store = dyn_cast<memref::StoreOp>(op)) {
      if (isMemRefSlot(store.getMemRef(), &ctx) &&
          isa<MemRefType>(store.getValueToStore().getType())) {
        Value slot = traceMemRef(store.getMemRef(), &ctx);
        ctx.memrefSlotAliases[slot] =
            resolveAlias(store.getValueToStore(), ctx);
      }
      return;
    }
    if (auto load = dyn_cast<memref::LoadOp>(op)) {
      if (!isMemRefSlot(load.getMemRef(), &ctx))
        return;
      Value slot = traceMemRef(load.getMemRef(), &ctx);
      auto it = ctx.memrefSlotAliases.find(slot);
      if (it != ctx.memrefSlotAliases.end() && it->second)
        ctx.valueAliases[load.getResult()] = it->second;
    }
  });
}

static void collectGenericAccesses(Operation *root, AccessStage &stage,
                                   llvm::DenseMap<Value, std::string> &buffers,
                                   GenericRaisingContext &ctx) {
  llvm::StringSet<> seenAccesses;
  llvm::StringSet<> seenProjections;
  llvm::StringMap<unsigned> seenAdvances;

  root->walk([&](Operation *op) {
    if (isInsideKnownDeadIf(op, ctx))
      return;

    if (auto call = dyn_cast<func::CallOp>(op)) {
      addGenericAdvance(stage, seenAdvances, call);
      return;
    }

    if (auto load = dyn_cast<memref::LoadOp>(op)) {
      if (isMemRefSlot(load.getMemRef(), &ctx)) {
        Value slot = traceMemRef(load.getMemRef(), &ctx);
        auto it = ctx.memrefSlotAliases.find(slot);
        if (it != ctx.memrefSlotAliases.end() && it->second)
          ctx.valueAliases[load.getResult()] = it->second;
        return;
      }

      SmallVector<Value> indexTerms;
      Value rootMemref =
          traceMemRefRootAndOffsets(load.getMemRef(), indexTerms, &ctx);
      if (isCudaIndexGlobalMemRef(rootMemref, &ctx))
        return;
      Value localIndex =
          load.getIndices().empty() ? Value() : load.getIndices()[0];
      if (localIndex && !isZeroConstant(localIndex))
        indexTerms.push_back(localIndex);
      std::string buffer = bufferName(rootMemref, buffers, &ctx);
      normalizeLinearizedBitGenStream(buffer, indexTerms, ctx);
      StringRef projectionKind;
      bool projected =
          loadHasOnlyFiniteStateProjection(load.getResult(), projectionKind);
      if (!indexTerms.empty()) {
        addGenericAccessWithIndexTerms(stage, seenAccesses, "read", buffer,
                                       indexTerms,
                                       bytesForMemRef(load.getMemRef()),
                                       "polygeist memref.load", ctx, projected);
        if (projected)
          addGenericStateProjectionWithIndexTerms(
              stage, seenProjections, buffer, indexTerms, ctx, projectionKind);
      } else {
        if (load.getIndices().empty())
          return;
        addGenericAccess(stage, seenAccesses, "read", buffer,
                         load.getIndices()[0], bytesForMemRef(load.getMemRef()),
                         "polygeist memref.load", ctx, projected);
        if (projected)
          addGenericStateProjection(stage, seenProjections, buffer,
                                    load.getIndices()[0], ctx, projectionKind);
      }
      return;
    }

    if (auto store = dyn_cast<memref::StoreOp>(op)) {
      if (isMemRefSlot(store.getMemRef(), &ctx) &&
          isa<MemRefType>(store.getValueToStore().getType())) {
        Value slot = traceMemRef(store.getMemRef(), &ctx);
        ctx.memrefSlotAliases[slot] =
            resolveAlias(store.getValueToStore(), ctx);
        return;
      }

      SmallVector<Value> indexTerms;
      Value rootMemref =
          traceMemRefRootAndOffsets(store.getMemRef(), indexTerms, &ctx);
      if (isCudaIndexGlobalMemRef(rootMemref, &ctx))
        return;
      Value localIndex =
          store.getIndices().empty() ? Value() : store.getIndices()[0];
      if (localIndex && !isZeroConstant(localIndex))
        indexTerms.push_back(localIndex);
      std::string buffer = bufferName(rootMemref, buffers, &ctx);
      normalizeLinearizedBitGenStream(buffer, indexTerms, ctx);
      if (!indexTerms.empty()) {
        addGenericAccessWithIndexTerms(
            stage, seenAccesses, "write", buffer, indexTerms,
            bytesForStoredValue(store.getValueToStore(), store.getMemRef()),
            "polygeist memref.store", ctx, false,
            finiteValueDomain(store.getValueToStore()));
      } else {
        if (store.getIndices().empty())
          return;
        addGenericAccess(
            stage, seenAccesses, "write", buffer, store.getIndices()[0],
            bytesForStoredValue(store.getValueToStore(), store.getMemRef()),
            "polygeist memref.store", ctx, false,
            finiteValueDomain(store.getValueToStore()));
      }
      return;
    }

    if (auto load = dyn_cast<affine::AffineLoadOp>(op)) {
      if (rememberMemRefSlotLoad(load, ctx))
        return;

      SmallVector<Value> indexTerms;
      Value rootMemref =
          traceMemRefRootAndOffsets(load.getMemref(), indexTerms, &ctx);
      if (isCudaIndexGlobalMemRef(rootMemref, &ctx))
        return;
      std::string buffer = affineAccessBufferName(load.getOperation(),
                                                  rootMemref, buffers, &ctx);
      normalizeLinearizedBitGenStream(buffer, indexTerms, ctx);
      StringRef projectionKind;
      bool projected =
          loadHasOnlyFiniteStateProjection(load.getResult(), projectionKind);
      bool projectionIsExclusive = projected;
      int64_t accessBytes = accessBytesForAffineLoad(load);
      if (!indexTerms.empty() && affineMapIsConstantZero(load.getAffineMap())) {
        addGenericAccessWithIndexTerms(
            stage, seenAccesses, "read", buffer, indexTerms, accessBytes,
            "polygeist affine.load", ctx, projectionIsExclusive, std::nullopt,
            load.getOperation());
        if (projected)
          addGenericStateProjectionWithIndexTerms(
              stage, seenProjections, buffer, indexTerms, ctx, projectionKind);
      } else {
        addGenericAffineAccess(
            stage, seenAccesses, "read", buffer, load.getAffineMap(),
            load.getMapOperands(), accessBytes, "polygeist affine.load", ctx,
            projectionIsExclusive, std::nullopt, load.getOperation());
        if (projected)
          addGenericAffineStateProjection(
              stage, seenProjections, buffer, load.getAffineMap(),
              load.getMapOperands(), ctx, projectionKind);
      }
      return;
    }

    if (auto store = dyn_cast<affine::AffineStoreOp>(op)) {
      if (rememberMemRefSlotStore(store, ctx))
        return;

      SmallVector<Value> indexTerms;
      Value rootMemref =
          traceMemRefRootAndOffsets(store.getMemref(), indexTerms, &ctx);
      if (isCudaIndexGlobalMemRef(rootMemref, &ctx))
        return;
      std::string buffer = affineAccessBufferName(store.getOperation(),
                                                  rootMemref, buffers, &ctx);
      normalizeLinearizedBitGenStream(buffer, indexTerms, ctx);
      if (!indexTerms.empty() &&
          affineMapIsConstantZero(store.getAffineMap())) {
        addGenericAccessWithIndexTerms(
            stage, seenAccesses, "write", buffer, indexTerms,
            accessBytesForAffineStore(store), "polygeist affine.store", ctx,
            false, finiteValueDomain(store.getValueToStore()));
      } else {
        addGenericAffineAccess(stage, seenAccesses, "write", buffer,
                               store.getAffineMap(), store.getMapOperands(),
                               accessBytesForAffineStore(store),
                               "polygeist affine.store", ctx, false,
                               finiteValueDomain(store.getValueToStore()));
      }
      return;
    }

    if (op->getName().getStringRef() == "llvm.store" &&
        op->getNumOperands() >= 2) {
      Value memref;
      Value index;
      if (!tracePointer(op->getOperand(1), memref, index, &ctx))
        return;
      if (isCudaIndexGlobalMemRef(memref, &ctx))
        return;
      std::string buffer = bufferName(memref, buffers, &ctx);
      SmallVector<Value> indexTerms;
      if (index)
        indexTerms.push_back(index);
      normalizeLinearizedBitGenStream(buffer, indexTerms, ctx);
      addGenericAccessWithIndexTerms(
          stage, seenAccesses, "write", buffer, indexTerms,
          bytesForStoredValue(op->getOperand(0), memref),
          "polygeist llvm.store", ctx, false,
          finiteValueDomain(op->getOperand(0)));
    }
  });
}

static void collectNestedBitGenCallAccesses(
    func::FuncOp caller, ModuleOp module, AccessStage &stage,
    llvm::DenseMap<Value, std::string> &buffers, GenericRaisingContext &ctx,
    unsigned depth = 0) {
  if (!caller || caller.empty() || depth > 3)
    return;

  caller.walk([&](func::CallOp call) {
    if (isInsideKnownDeadIf(call.getOperation(), ctx))
      return;

    StringRef calleeName = call.getCallee();
    if (!isBitGenLikeName(calleeName))
      return;

    func::FuncOp callee = module.lookupSymbol<func::FuncOp>(calleeName);
    if (!callee || callee.empty())
      return;

    GenericRaisingContext nestedCtx = ctx;
    nestedCtx.enableBitGenLinearizedStreams = true;
    Block &entry = callee.front();
    for (auto [arg, operand] :
         llvm::zip(entry.getArguments(), call.getOperands()))
      nestedCtx.valueAliases[arg] = resolveAlias(operand, ctx);

    collectGenericAccesses(callee.getOperation(), stage, buffers, nestedCtx);
    collectNestedBitGenCallAccesses(callee, module, stage, buffers, nestedCtx,
                                    depth + 1);
  });
}

static bool isScanCall(func::CallOp call) {
  StringRef callee = call.getCallee();
  return callee.contains("scan") || callee.contains("exclusive_scan");
}

static std::optional<AccessStage>
raiseScanCall(func::CallOp call, llvm::DenseMap<Value, std::string> &buffers) {
  if (!isScanCall(call) || call.getNumOperands() < 2)
    return std::nullopt;

  AccessStage stage;
  stage.name = sanitize(call.getCallee());
  stage.kind = "scan";
  stage.recoveryRule =
      "polygeist generic MLIR raising: scan call is an explicit stage";
  std::string input = bufferName(call.getOperand(0), buffers);
  std::string output = bufferName(call.getOperand(1), buffers);
  stage.actions.push_back(action({{"kind", "read"},
                                  {"buffer", input},
                                  {"index", "logical"},
                                  {"index_kind", "logical"},
                                  {"bytes", "4"},
                                  {"meaning", "polygeist scan input"}}));
  stage.actions.push_back(action({{"kind", "write"},
                                  {"buffer", output},
                                  {"index", "logical"},
                                  {"index_kind", "logical"},
                                  {"bytes", "4"},
                                  {"meaning", "polygeist scan output"}}));
  return stage;
}

static std::optional<AccessStage>
raiseScanCallInside(Operation *root,
                    llvm::DenseMap<Value, std::string> &buffers) {
  std::optional<AccessStage> result;
  root->walk([&](func::CallOp call) {
    if (result || !isScanCall(call))
      return;
    result = raiseScanCall(call, buffers);
  });
  if (result)
    result->recoveryRule =
        "polygeist direct-CUDA raising: scan call inside launch wrapper";
  return result;
}

static std::optional<AccessStage>
raiseKernelCall(func::CallOp call, ModuleOp module,
                llvm::DenseMap<Value, std::string> &buffers,
                const GenericRaisingContext &parentCtx) {
  func::FuncOp callee = module.lookupSymbol<func::FuncOp>(call.getCallee());
  if ((!callee || callee.empty()) && isScanCall(call))
    return raiseScanCall(call, buffers);

  if (!callee || callee.empty())
    return std::nullopt;

  AccessStage stage;
  stage.name = sanitize(call.getCallee());
  stage.kind = "kernel";
  stage.recoveryRule = "polygeist generic MLIR raising: driver call stage "
                       "summarized from callee body";

  GenericRaisingContext ctx = parentCtx;
  ctx.enableBitGenLinearizedStreams = isBitGenLikeName(call.getCallee()) ||
                                      isBitGenLikeName(callee.getSymName());
  Block &entry = callee.front();
  for (auto [arg, operand] :
       llvm::zip(entry.getArguments(), call.getOperands()))
    ctx.valueAliases[arg] = resolveAlias(operand, ctx);

  selectUniqueTopLevelCoordinateLoop(callee.getOperation(), ctx);
  selectStructuredDataCoordinates(callee.getOperation(), ctx);
  collectGenericAccesses(callee.getOperation(), stage, buffers, ctx);
  if (ctx.enableBitGenLinearizedStreams)
    collectNestedBitGenCallAccesses(callee, module, stage, buffers, ctx);
  if (stage.actions.empty())
    return std::nullopt;
  return stage;
}

static int64_t countTopLevelStages(func::FuncOp func) {
  if (func.empty())
    return 0;
  int64_t count = 0;
  for (Operation &op : func.front().without_terminator()) {
    if (isa<affine::AffineForOp, affine::AffineParallelOp, scf::ForOp,
            scf::WhileOp, scf::ParallelOp>(&op))
      ++count;
    if (op.getName().getStringRef() == "polygeist.gpu_block")
      ++count;
    if (isa<func::CallOp>(&op))
      ++count;
  }
  return count;
}

static func::FuncOp chooseGenericDriver(ModuleOp module) {
  if (const char *requested = std::getenv("BITSTREAM_POLYGEIST_DRIVER")) {
    if (requested[0] != '\0') {
      if (func::FuncOp selected =
              module.lookupSymbol<func::FuncOp>(StringRef(requested)))
        return selected;
    }
  }

  func::FuncOp best = nullptr;
  int64_t bestStages = 0;
  module.walk([&](func::FuncOp func) {
    int64_t stages = countTopLevelStages(func);
    if (func.getSymName().contains("driver") && stages > 0) {
      best = func;
      bestStages = stages;
      return;
    }
    if (stages > bestStages) {
      best = func;
      bestStages = stages;
    }
  });
  return best;
}

static SmallVector<AccessStage>
raiseGenericDriver(func::FuncOp driver,
                   llvm::DenseMap<Value, std::string> &buffers,
                   ModuleOp module) {
  SmallVector<AccessStage> stages;
  if (!driver.getOperation() || driver.empty())
    return stages;

  GenericRaisingContext preludeCtx;
  preludeCtx.rootDriver = driver;
  preludeCtx.enableBitGenLinearizedStreams =
      isBitGenLikeName(driver.getSymName());
  int64_t ordinal = 0;
  for (Operation &op : driver.front().without_terminator()) {
    if (auto loop = dyn_cast<affine::AffineParallelOp>(&op)) {
      AccessStage stage;
      stage.name = ("polygeist_stage" + Twine(ordinal++)).str();
      stage.kind =
          hasUnitOrBoolAttr(&op, "bitstream.scan_stage")
              ? "scan"
              : getStringAttr(&op, "bitstream.stage_kind", "kernel").str();
      stage.recoveryRule =
          "polygeist generic MLIR raising: top-level affine.parallel stage";
      GenericRaisingContext ctx = preludeCtx;
      selectPrimaryCoordinateLoop(ctx, loop.getOperation());
      selectStructuredDataCoordinates(loop.getOperation(), ctx);
      collectGenericAccesses(loop.getOperation(), stage, buffers, ctx);
      if (!stage.actions.empty())
        stages.push_back(std::move(stage));
      continue;
    }
    if (auto loop = dyn_cast<affine::AffineForOp>(&op)) {
      AccessStage stage;
      stage.name = ("polygeist_stage" + Twine(ordinal++)).str();
      stage.kind =
          hasUnitOrBoolAttr(&op, "bitstream.scan_stage")
              ? "scan"
              : getStringAttr(&op, "bitstream.stage_kind", "kernel").str();
      stage.recoveryRule =
          "polygeist generic MLIR raising: top-level affine.for stage";
      GenericRaisingContext ctx = preludeCtx;
      selectPrimaryCoordinateLoop(ctx, loop.getOperation());
      selectStructuredDataCoordinates(loop.getOperation(), ctx);
      collectGenericAccesses(loop.getOperation(), stage, buffers, ctx);
      if (!stage.actions.empty())
        stages.push_back(std::move(stage));
      continue;
    }
    if (auto loop = dyn_cast<scf::ForOp>(&op)) {
      AccessStage stage;
      stage.name = ("polygeist_stage" + Twine(ordinal++)).str();
      stage.kind = "kernel";
      stage.recoveryRule =
          "polygeist generic MLIR raising: top-level scf.for stage";
      GenericRaisingContext ctx = preludeCtx;
      selectPrimaryCoordinateLoop(ctx, loop.getOperation());
      selectStructuredDataCoordinates(loop.getOperation(), ctx);
      collectGenericAccesses(&op, stage, buffers, ctx);
      if (!stage.actions.empty())
        stages.push_back(std::move(stage));
      continue;
    }
    if (auto loop = dyn_cast<scf::WhileOp>(&op)) {
      AccessStage stage;
      stage.name = ("polygeist_stage" + Twine(ordinal++)).str();
      stage.kind = "kernel";
      stage.recoveryRule =
          "polygeist generic MLIR raising: top-level scf.while stage";
      GenericRaisingContext ctx = preludeCtx;
      selectPrimaryCoordinateLoop(ctx, loop.getOperation());
      selectStructuredDataCoordinates(loop.getOperation(), ctx);
      collectGenericAccesses(&op, stage, buffers, ctx);
      if (!stage.actions.empty())
        stages.push_back(std::move(stage));
      continue;
    }
    if (auto loop = dyn_cast<scf::ParallelOp>(&op)) {
      if (auto scanStage = raiseScanCallInside(loop.getOperation(), buffers)) {
        scanStage->name = ("polygeist_stage" + Twine(ordinal++) + "_" +
                           Twine(scanStage->name))
                              .str();
        stages.push_back(*scanStage);
        continue;
      }
      AccessStage stage;
      stage.name = ("polygeist_stage" + Twine(ordinal++)).str();
      stage.kind = "kernel";
      stage.recoveryRule =
          "polygeist direct-CUDA raising: top-level scf.parallel stage";
      GenericRaisingContext ctx = preludeCtx;
      selectPrimaryCoordinateLoop(ctx, loop.getOperation());
      selectStructuredDataCoordinates(loop.getOperation(), ctx);
      collectGenericAccesses(loop.getOperation(), stage, buffers, ctx);
      if (!stage.actions.empty())
        stages.push_back(std::move(stage));
      continue;
    }
    if (op.getName().getStringRef() == "polygeist.gpu_block") {
      AccessStage stage;
      stage.name = ("polygeist_stage" + Twine(ordinal++)).str();
      stage.kind = "kernel";
      stage.recoveryRule =
          "polygeist direct-CUDA raising: polygeist.gpu_block/gpu_thread stage";
      GenericRaisingContext ctx = preludeCtx;
      collectGenericAccesses(&op, stage, buffers, ctx);
      if (!stage.actions.empty())
        stages.push_back(std::move(stage));
      continue;
    }
    if (auto call = dyn_cast<func::CallOp>(&op)) {
      if (auto stage = raiseKernelCall(call, module, buffers, preludeCtx)) {
        stages.push_back(*stage);
        ++ordinal;
      }
      continue;
    }
    collectGenericAliasFacts(&op, preludeCtx);
  }
  return stages;
}

static PipelineOp
materializeRecoveredPipeline(ModuleOp module, Location loc, StringRef name,
                             ArrayRef<AccessStage> recovered) {
  OpBuilder builder(module.getContext());
  builder.setInsertionPointToEnd(module.getBody());

  OperationState pipelineState(loc, PipelineOp::getOperationName());
  pipelineState.addAttribute(SymbolTable::getSymbolAttrName(),
                             builder.getStringAttr(name));
  Region *pipelineRegion = pipelineState.addRegion();
  pipelineRegion->push_back(new Block());
  auto pipeline = cast<PipelineOp>(builder.create(pipelineState));
  OpBuilder::atBlockEnd(&pipeline.getBody().front()).create<YieldOp>(loc);

  SmallVector<std::string> bufferOrder;
  llvm::StringSet<> seenBuffers;
  for (const AccessStage &stage : recovered)
    for (const AccessAction &act : stage.actions)
      collectBuffers(act, bufferOrder, seenBuffers);
  Operation *terminator = pipeline.getBody().front().getTerminator();
  builder.setInsertionPoint(terminator);

  llvm::DenseMap<int64_t, Value> parameterValues;
  for (int64_t sourceArg : collectPipelineParameterOrdinals(recovered)) {
    Operation *parameter = createPipelineParameter(builder, loc, sourceArg);
    parameterValues[sourceArg] = parameter->getResult(0);
  }

  llvm::StringMap<Value> bufferValues;
  for (StringRef bufferName : bufferOrder) {
    Operation *bufferOp = createBuffer(builder, loc, bufferName);
    bufferValues[bufferName] = bufferOp->getResult(0);
  }

  for (const AccessStage &stage : recovered) {
    Operation *stageOp = createStageShell(builder, loc, stage);
    OpBuilder stageBuilder =
        OpBuilder::atBlockEnd(&stageOp->getRegion(0).front());
    IndexScope indices;
    indices.parameters = &parameterValues;
    materializeActionsDirectly(stageBuilder, loc, bufferValues, indices,
                               stage.actions);
    stageBuilder.create<YieldOp>(loc);
  }
  assignAccessIds(pipeline);
  return pipeline;
}

static void eraseGenericMlirOps(ModuleOp module) {
  SmallVector<Operation *> erase;
  for (Operation &op : module.getBody()->without_terminator()) {
    if (isa<PipelineOp>(&op) || isa<AnalysisOp>(&op))
      continue;
    erase.push_back(&op);
  }
  for (Operation *op : erase)
    op->erase();
}

static void stripFrontendModuleAttrs(ModuleOp module) {
  SmallVector<NamedAttribute> keep;
  for (NamedAttribute attr : module->getAttrs()) {
    StringRef name = attr.getName().getValue();
    if (name.starts_with("bitstream."))
      keep.push_back(attr);
  }
  module->setAttrs(DictionaryAttr::get(module.getContext(), keep));
}

static bool recoverFromGenericMlir(ModuleOp module) {
  func::FuncOp driver = chooseGenericDriver(module);
  if (!driver.getOperation())
    return false;

  llvm::DenseMap<Value, std::string> buffers;
  SmallVector<AccessStage> recovered =
      raiseGenericDriver(driver, buffers, module);
  if (recovered.empty())
    return false;
  pruneStageLocalSyntheticBuffers(recovered);

  std::string driverName = driver.getSymName().str();
  std::string pipelineName = sanitize(driverName) + "_polygeist_raised";
  PipelineOp pipeline = materializeRecoveredPipeline(module, driver.getLoc(),
                                                     pipelineName, recovered);
  eraseGenericMlirOps(module);
  stripFrontendModuleAttrs(module);
  pipeline.emitRemark() << "bitstream access-graph recovery emitted "
                        << recovered.size()
                        << " stages from Polygeist generic MLIR driver "
                        << driverName;
  return true;
}

struct BitstreamRecoverSemanticsPass
    : bitstream::impl::BitstreamRecoverSemanticsBase<
          BitstreamRecoverSemanticsPass> {
  void runOnOperation() override {
    ModuleOp module = getOperation();
    module.getContext()->getOrLoadDialect<affine::AffineDialect>();
    module.getContext()->getOrLoadDialect<arith::ArithDialect>();
    module.getContext()->getOrLoadDialect<gpu::GPUDialect>();
    module.getContext()->getOrLoadDialect<func::FuncDialect>();
    module.getContext()->getOrLoadDialect<memref::MemRefDialect>();
    module.getContext()->getOrLoadDialect<scf::SCFDialect>();
    SmallVector<PipelineOp> pipelines;
    module.walk([&](PipelineOp pipeline) {
      if (getStringAttr(pipeline.getOperation(),
                        SymbolTable::getSymbolAttrName())
              .ends_with("_ast_facts"))
        pipelines.push_back(pipeline);
    });

    for (PipelineOp pipeline : pipelines) {
      SmallVector<FunctionFacts> stages;
      readFactGroups(pipeline, stages);

      llvm::sort(stages, [](const FunctionFacts &a, const FunctionFacts &b) {
        const Fact *entryA = findFactByRole(a, "entry_call");
        const Fact *entryB = findFactByRole(b, "entry_call");
        int64_t orderA =
            entryA ? parseInteger(getAttr(*entryA, "order")).value_or(0) : 0;
        int64_t orderB =
            entryB ? parseInteger(getAttr(*entryB, "order")).value_or(0) : 0;
        return orderA < orderB;
      });

      SmallVector<AccessStage> recovered;
      for (const FunctionFacts &stage : stages)
        if (auto result = recoverStage(stage))
          recovered.push_back(*result);
      pruneStageLocalSyntheticBuffers(recovered);

      SmallVector<std::string> bufferOrder;
      llvm::StringSet<> seenBuffers;
      for (const AccessStage &stage : recovered)
        for (const AccessAction &act : stage.actions)
          collectBuffers(act, bufferOrder, seenBuffers);
      SmallVector<Operation *> oldFactOps;
      for (Operation &op : pipeline.getBody().front())
        if (isa<FactGroupOp>(&op))
          oldFactOps.push_back(&op);
      for (Operation *op : oldFactOps)
        op->erase();

      std::string oldName = getStringAttr(pipeline.getOperation(),
                                          SymbolTable::getSymbolAttrName())
                                .str();
      std::string newName = oldName;
      if (StringRef(newName).ends_with("_ast_facts"))
        newName.resize(newName.size() - StringRef("_ast_facts").size());
      pipeline->setAttr(SymbolTable::getSymbolAttrName(),
                        StringAttr::get(pipeline.getContext(), newName));

      OpBuilder builder(pipeline.getContext());
      Operation *terminator = pipeline.getBody().front().getTerminator();
      builder.setInsertionPoint(terminator);

      llvm::DenseMap<int64_t, Value> parameterValues;
      for (int64_t sourceArg : collectPipelineParameterOrdinals(recovered)) {
        Operation *parameter =
            createPipelineParameter(builder, pipeline.getLoc(), sourceArg);
        parameterValues[sourceArg] = parameter->getResult(0);
      }

      llvm::StringMap<Value> buffers;
      for (StringRef name : bufferOrder) {
        Operation *bufferOp = createBuffer(builder, pipeline.getLoc(), name);
        buffers[name] = bufferOp->getResult(0);
      }

      for (const AccessStage &stage : recovered) {
        Operation *stageOp =
            createStageShell(builder, pipeline.getLoc(), stage);
        OpBuilder stageBuilder =
            OpBuilder::atBlockEnd(&stageOp->getRegion(0).front());
        IndexScope indices;
        indices.parameters = &parameterValues;
        materializeActionsDirectly(stageBuilder, pipeline.getLoc(), buffers,
                                   indices, stage.actions);
        stageBuilder.create<YieldOp>(pipeline.getLoc());
      }

      assignAccessIds(pipeline);

      pipeline.emitRemark()
          << "bitstream access-graph recovery emitted " << recovered.size()
          << " stages and " << bufferOrder.size()
          << " logical buffers from neutral AST facts";
    }

    if (pipelines.empty() && !recoverFromGenericMlir(module))
      stripFrontendModuleAttrs(module);
  }
};

} // namespace

std::unique_ptr<Pass> bitstream::createBitstreamRecoverSemanticsPass() {
  return std::make_unique<BitstreamRecoverSemanticsPass>();
}
