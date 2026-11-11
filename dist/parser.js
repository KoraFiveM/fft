(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
    get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
  }) : x)(function(x) {
    if (typeof require !== "undefined") return require.apply(this, arguments);
    throw Error('Dynamic require of "' + x + '" is not supported');
  });
  var __esm = (fn, res) => function __init() {
    return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
  };
  var __commonJS = (cb, mod) => function __require2() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // node_modules/@cucumber/gherkin/dist/src/Errors.js
  var require_Errors = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/Errors.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.NoSuchLanguageException = exports.AstBuilderException = exports.CompositeParserException = exports.ParserException = exports.GherkinException = void 0;
      var GherkinException = class extends Error {
        constructor(message2) {
          super(message2);
          const actualProto = new.target.prototype;
          if (Object.setPrototypeOf) {
            Object.setPrototypeOf(this, actualProto);
          } else {
            this.__proto__ = actualProto;
          }
        }
        static _create(message2, location) {
          const column = location != null ? location.column || 0 : -1;
          const line = location != null ? location.line || 0 : -1;
          const m = `(${line}:${column}): ${message2}`;
          const err = new this(m);
          err.location = location;
          return err;
        }
      };
      exports.GherkinException = GherkinException;
      var ParserException = class extends GherkinException {
        static create(message2, line, column) {
          const err = new this(`(${line}:${column}): ${message2}`);
          err.location = { line, column };
          return err;
        }
      };
      exports.ParserException = ParserException;
      var CompositeParserException = class extends GherkinException {
        static create(errors) {
          const message2 = "Parser errors:\n" + errors.map((e) => e.message).join("\n");
          const err = new this(message2);
          err.errors = errors;
          return err;
        }
      };
      exports.CompositeParserException = CompositeParserException;
      var AstBuilderException = class extends GherkinException {
        static create(message2, location) {
          return this._create(message2, location);
        }
      };
      exports.AstBuilderException = AstBuilderException;
      var NoSuchLanguageException = class extends GherkinException {
        static create(language, location) {
          const message2 = "Language not supported: " + language;
          return this._create(message2, location);
        }
      };
      exports.NoSuchLanguageException = NoSuchLanguageException;
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/TokenExceptions.js
  var require_TokenExceptions = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/TokenExceptions.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.UnexpectedEOFException = exports.UnexpectedTokenException = void 0;
      var Errors_1 = require_Errors();
      var UnexpectedTokenException = class extends Errors_1.GherkinException {
        static create(token, expectedTokenTypes) {
          const message2 = `expected: ${expectedTokenTypes.join(", ")}, got '${token.getTokenValue().trim()}'`;
          const location = tokenLocation(token);
          return this._create(message2, location);
        }
      };
      exports.UnexpectedTokenException = UnexpectedTokenException;
      var UnexpectedEOFException = class extends Errors_1.GherkinException {
        static create(token, expectedTokenTypes) {
          const message2 = `unexpected end of file, expected: ${expectedTokenTypes.join(", ")}`;
          const location = tokenLocation(token);
          return this._create(message2, location);
        }
      };
      exports.UnexpectedEOFException = UnexpectedEOFException;
      function tokenLocation(token) {
        return token.location && token.location.line && token.line && token.line.indent !== void 0 ? {
          line: token.location.line,
          column: token.line.indent + 1
        } : token.location;
      }
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/TokenScanner.js
  var require_TokenScanner = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/TokenScanner.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      var TokenScanner = class {
        constructor(source, makeToken) {
          this.makeToken = makeToken;
          this.lineNumber = 0;
          this.lines = source.split(/\r?\n/);
          if (this.lines.length > 0 && this.lines[this.lines.length - 1].trim() === "") {
            this.lines.pop();
          }
        }
        read() {
          const line = this.lines[this.lineNumber++];
          const location = {
            line: this.lineNumber
          };
          return this.makeToken(line, location);
        }
      };
      exports.default = TokenScanner;
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/countSymbols.js
  var require_countSymbols = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/countSymbols.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.default = countSymbols;
      var regexAstralSymbols = /[\uD800-\uDBFF][\uDC00-\uDFFF]/g;
      function countSymbols(s) {
        return s.replace(regexAstralSymbols, "_").length;
      }
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/GherkinLine.js
  var require_GherkinLine = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/GherkinLine.js"(exports, module) {
      "use strict";
      var __importDefault = exports && exports.__importDefault || function(mod) {
        return mod && mod.__esModule ? mod : { "default": mod };
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      var countSymbols_1 = __importDefault(require_countSymbols());
      var GherkinLine = class {
        constructor(lineText, lineNumber) {
          this.lineText = lineText;
          this.lineNumber = lineNumber;
          this.trimmedLineText = lineText.replace(/^\s+/g, "");
          this.isEmpty = this.trimmedLineText.length === 0;
          this.indent = (0, countSymbols_1.default)(lineText) - (0, countSymbols_1.default)(this.trimmedLineText);
        }
        startsWith(prefix) {
          return this.trimmedLineText.indexOf(prefix) === 0;
        }
        startsWithTitleKeyword(keyword) {
          return this.startsWith(keyword + ":");
        }
        match(regexp) {
          return this.trimmedLineText.match(regexp);
        }
        getLineText(indentToRemove) {
          if (indentToRemove < 0 || indentToRemove > this.indent) {
            return this.trimmedLineText;
          } else {
            return this.lineText.substring(indentToRemove);
          }
        }
        getRestTrimmed(length) {
          return this.trimmedLineText.substring(length).trim();
        }
        getTableCells() {
          const cells = [];
          let col = 0;
          let startCol = col + 1;
          let cell = "";
          let firstCell = true;
          while (col < this.trimmedLineText.length) {
            let chr = this.trimmedLineText[col];
            col++;
            if (chr === "|") {
              if (firstCell) {
                firstCell = false;
              } else {
                const trimmedLeft = cell.replace(/^[ \t\v\f\r\u0085\u00A0]*/g, "");
                const trimmed = trimmedLeft.replace(/[ \t\v\f\r\u0085\u00A0]*$/g, "");
                const cellIndent = cell.length - trimmedLeft.length;
                const span = {
                  column: this.indent + startCol + cellIndent,
                  text: trimmed
                };
                cells.push(span);
              }
              cell = "";
              startCol = col + 1;
            } else if (chr === "\\") {
              chr = this.trimmedLineText[col];
              col += 1;
              if (chr === "n") {
                cell += "\n";
              } else {
                if (chr !== "|" && chr !== "\\") {
                  cell += "\\";
                }
                cell += chr;
              }
            } else {
              cell += chr;
            }
          }
          return cells;
        }
      };
      exports.default = GherkinLine;
      module.exports = GherkinLine;
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/Parser.js
  var require_Parser = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/Parser.js"(exports) {
      "use strict";
      var __importDefault = exports && exports.__importDefault || function(mod) {
        return mod && mod.__esModule ? mod : { "default": mod };
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.RuleType = exports.TokenType = exports.Token = void 0;
      var Errors_1 = require_Errors();
      var TokenExceptions_1 = require_TokenExceptions();
      var TokenScanner_1 = __importDefault(require_TokenScanner());
      var GherkinLine_1 = __importDefault(require_GherkinLine());
      var Token2 = class {
        constructor(line, location) {
          this.line = line;
          this.location = location;
          this.isEof = !line;
        }
        getTokenValue() {
          return this.isEof ? "EOF" : this.line.getLineText(-1);
        }
        detach() {
        }
      };
      exports.Token = Token2;
      var TokenType2;
      (function(TokenType3) {
        TokenType3[TokenType3["None"] = 0] = "None";
        TokenType3[TokenType3["EOF"] = 1] = "EOF";
        TokenType3[TokenType3["Empty"] = 2] = "Empty";
        TokenType3[TokenType3["Comment"] = 3] = "Comment";
        TokenType3[TokenType3["TagLine"] = 4] = "TagLine";
        TokenType3[TokenType3["FeatureLine"] = 5] = "FeatureLine";
        TokenType3[TokenType3["RuleLine"] = 6] = "RuleLine";
        TokenType3[TokenType3["BackgroundLine"] = 7] = "BackgroundLine";
        TokenType3[TokenType3["ScenarioLine"] = 8] = "ScenarioLine";
        TokenType3[TokenType3["ExamplesLine"] = 9] = "ExamplesLine";
        TokenType3[TokenType3["StepLine"] = 10] = "StepLine";
        TokenType3[TokenType3["DocStringSeparator"] = 11] = "DocStringSeparator";
        TokenType3[TokenType3["TableRow"] = 12] = "TableRow";
        TokenType3[TokenType3["Language"] = 13] = "Language";
        TokenType3[TokenType3["Other"] = 14] = "Other";
      })(TokenType2 || (exports.TokenType = TokenType2 = {}));
      var RuleType;
      (function(RuleType2) {
        RuleType2[RuleType2["None"] = 0] = "None";
        RuleType2[RuleType2["_EOF"] = 1] = "_EOF";
        RuleType2[RuleType2["_Empty"] = 2] = "_Empty";
        RuleType2[RuleType2["_Comment"] = 3] = "_Comment";
        RuleType2[RuleType2["_TagLine"] = 4] = "_TagLine";
        RuleType2[RuleType2["_FeatureLine"] = 5] = "_FeatureLine";
        RuleType2[RuleType2["_RuleLine"] = 6] = "_RuleLine";
        RuleType2[RuleType2["_BackgroundLine"] = 7] = "_BackgroundLine";
        RuleType2[RuleType2["_ScenarioLine"] = 8] = "_ScenarioLine";
        RuleType2[RuleType2["_ExamplesLine"] = 9] = "_ExamplesLine";
        RuleType2[RuleType2["_StepLine"] = 10] = "_StepLine";
        RuleType2[RuleType2["_DocStringSeparator"] = 11] = "_DocStringSeparator";
        RuleType2[RuleType2["_TableRow"] = 12] = "_TableRow";
        RuleType2[RuleType2["_Language"] = 13] = "_Language";
        RuleType2[RuleType2["_Other"] = 14] = "_Other";
        RuleType2[RuleType2["GherkinDocument"] = 15] = "GherkinDocument";
        RuleType2[RuleType2["Feature"] = 16] = "Feature";
        RuleType2[RuleType2["FeatureHeader"] = 17] = "FeatureHeader";
        RuleType2[RuleType2["Rule"] = 18] = "Rule";
        RuleType2[RuleType2["RuleHeader"] = 19] = "RuleHeader";
        RuleType2[RuleType2["Background"] = 20] = "Background";
        RuleType2[RuleType2["ScenarioDefinition"] = 21] = "ScenarioDefinition";
        RuleType2[RuleType2["Scenario"] = 22] = "Scenario";
        RuleType2[RuleType2["ExamplesDefinition"] = 23] = "ExamplesDefinition";
        RuleType2[RuleType2["Examples"] = 24] = "Examples";
        RuleType2[RuleType2["ExamplesTable"] = 25] = "ExamplesTable";
        RuleType2[RuleType2["Step"] = 26] = "Step";
        RuleType2[RuleType2["StepArg"] = 27] = "StepArg";
        RuleType2[RuleType2["DataTable"] = 28] = "DataTable";
        RuleType2[RuleType2["DocString"] = 29] = "DocString";
        RuleType2[RuleType2["Tags"] = 30] = "Tags";
        RuleType2[RuleType2["DescriptionHelper"] = 31] = "DescriptionHelper";
        RuleType2[RuleType2["Description"] = 32] = "Description";
      })(RuleType || (exports.RuleType = RuleType = {}));
      var Parser2 = class {
        constructor(builder, tokenMatcher) {
          this.builder = builder;
          this.tokenMatcher = tokenMatcher;
          this.stopAtFirstError = false;
        }
        parse(gherkinSource) {
          const tokenScanner = new TokenScanner_1.default(gherkinSource, (line, location) => {
            const gherkinLine = line === null || line === void 0 ? null : new GherkinLine_1.default(line, location.line);
            return new Token2(gherkinLine, location);
          });
          this.builder.reset();
          this.tokenMatcher.reset();
          this.context = {
            tokenScanner,
            tokenQueue: [],
            errors: []
          };
          this.startRule(this.context, RuleType.GherkinDocument);
          let state = 0;
          let token = null;
          while (true) {
            token = this.readToken(this.context);
            state = this.matchToken(state, token, this.context);
            if (token.isEof)
              break;
          }
          this.endRule(this.context);
          if (this.context.errors.length > 0) {
            throw Errors_1.CompositeParserException.create(this.context.errors);
          }
          return this.getResult();
        }
        addError(context, error) {
          if (!context.errors.map((e) => {
            return e.message;
          }).includes(error.message)) {
            context.errors.push(error);
            if (context.errors.length > 10)
              throw Errors_1.CompositeParserException.create(context.errors);
          }
        }
        startRule(context, ruleType) {
          this.handleAstError(context, () => this.builder.startRule(ruleType));
        }
        endRule(context) {
          this.handleAstError(context, () => this.builder.endRule());
        }
        build(context, token) {
          this.handleAstError(context, () => this.builder.build(token));
        }
        getResult() {
          return this.builder.getResult();
        }
        handleAstError(context, action) {
          this.handleExternalError(context, true, action);
        }
        handleExternalError(context, defaultValue, action) {
          if (this.stopAtFirstError)
            return action();
          try {
            return action();
          } catch (e) {
            if (e instanceof Errors_1.CompositeParserException) {
              e.errors.forEach((error) => this.addError(context, error));
            } else if (e instanceof Errors_1.ParserException || e instanceof Errors_1.AstBuilderException || e instanceof TokenExceptions_1.UnexpectedTokenException || e instanceof Errors_1.NoSuchLanguageException) {
              this.addError(context, e);
            } else {
              throw e;
            }
          }
          return defaultValue;
        }
        readToken(context) {
          return context.tokenQueue.length > 0 ? context.tokenQueue.shift() : context.tokenScanner.read();
        }
        matchToken(state, token, context) {
          switch (state) {
            case 0:
              return this.matchTokenAt_0(token, context);
            case 1:
              return this.matchTokenAt_1(token, context);
            case 2:
              return this.matchTokenAt_2(token, context);
            case 3:
              return this.matchTokenAt_3(token, context);
            case 4:
              return this.matchTokenAt_4(token, context);
            case 5:
              return this.matchTokenAt_5(token, context);
            case 6:
              return this.matchTokenAt_6(token, context);
            case 7:
              return this.matchTokenAt_7(token, context);
            case 8:
              return this.matchTokenAt_8(token, context);
            case 9:
              return this.matchTokenAt_9(token, context);
            case 10:
              return this.matchTokenAt_10(token, context);
            case 11:
              return this.matchTokenAt_11(token, context);
            case 12:
              return this.matchTokenAt_12(token, context);
            case 13:
              return this.matchTokenAt_13(token, context);
            case 14:
              return this.matchTokenAt_14(token, context);
            case 15:
              return this.matchTokenAt_15(token, context);
            case 16:
              return this.matchTokenAt_16(token, context);
            case 17:
              return this.matchTokenAt_17(token, context);
            case 18:
              return this.matchTokenAt_18(token, context);
            case 19:
              return this.matchTokenAt_19(token, context);
            case 20:
              return this.matchTokenAt_20(token, context);
            case 21:
              return this.matchTokenAt_21(token, context);
            case 22:
              return this.matchTokenAt_22(token, context);
            case 23:
              return this.matchTokenAt_23(token, context);
            case 24:
              return this.matchTokenAt_24(token, context);
            case 25:
              return this.matchTokenAt_25(token, context);
            case 26:
              return this.matchTokenAt_26(token, context);
            case 27:
              return this.matchTokenAt_27(token, context);
            case 28:
              return this.matchTokenAt_28(token, context);
            case 29:
              return this.matchTokenAt_29(token, context);
            case 30:
              return this.matchTokenAt_30(token, context);
            case 31:
              return this.matchTokenAt_31(token, context);
            case 32:
              return this.matchTokenAt_32(token, context);
            case 33:
              return this.matchTokenAt_33(token, context);
            case 35:
              return this.matchTokenAt_35(token, context);
            case 36:
              return this.matchTokenAt_36(token, context);
            case 37:
              return this.matchTokenAt_37(token, context);
            case 38:
              return this.matchTokenAt_38(token, context);
            case 39:
              return this.matchTokenAt_39(token, context);
            case 40:
              return this.matchTokenAt_40(token, context);
            case 41:
              return this.matchTokenAt_41(token, context);
            case 42:
              return this.matchTokenAt_42(token, context);
            default:
              throw new Error("Unknown state: " + state);
          }
        }
        // Start
        matchTokenAt_0(token, context) {
          if (this.match_EOF(context, token)) {
            this.build(context, token);
            return 34;
          }
          if (this.match_Language(context, token)) {
            this.startRule(context, RuleType.Feature);
            this.startRule(context, RuleType.FeatureHeader);
            this.build(context, token);
            return 1;
          }
          if (this.match_TagLine(context, token)) {
            this.startRule(context, RuleType.Feature);
            this.startRule(context, RuleType.FeatureHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 2;
          }
          if (this.match_FeatureLine(context, token)) {
            this.startRule(context, RuleType.Feature);
            this.startRule(context, RuleType.FeatureHeader);
            this.build(context, token);
            return 3;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 0;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 0;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Language", "#TagLine", "#FeatureLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 0;
        }
        // GherkinDocument:0>Feature:0>FeatureHeader:0>#Language:0
        matchTokenAt_1(token, context) {
          if (this.match_TagLine(context, token)) {
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 2;
          }
          if (this.match_FeatureLine(context, token)) {
            this.build(context, token);
            return 3;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 1;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 1;
          }
          token.detach();
          const expectedTokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 1;
        }
        // GherkinDocument:0>Feature:0>FeatureHeader:1>Tags:0>#TagLine:0
        matchTokenAt_2(token, context) {
          if (this.match_TagLine(context, token)) {
            this.build(context, token);
            return 2;
          }
          if (this.match_FeatureLine(context, token)) {
            this.endRule(context);
            this.build(context, token);
            return 3;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 2;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 2;
          }
          token.detach();
          const expectedTokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 2;
        }
        // GherkinDocument:0>Feature:0>FeatureHeader:2>#FeatureLine:0
        matchTokenAt_3(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 3;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 4;
          }
          if (this.match_BackgroundLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Background);
            this.build(context, token);
            return 5;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 4;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 3;
        }
        // GherkinDocument:0>Feature:0>FeatureHeader:3>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_4(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 4;
          }
          if (this.match_BackgroundLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Background);
            this.build(context, token);
            return 5;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 4;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 4;
        }
        // GherkinDocument:0>Feature:1>Background:0>#BackgroundLine:0
        matchTokenAt_5(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 5;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 6;
          }
          if (this.match_StepLine(context, token)) {
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 7;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 6;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 5;
        }
        // GherkinDocument:0>Feature:1>Background:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_6(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 6;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 7;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 6;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 6;
        }
        // GherkinDocument:0>Feature:1>Background:2>Step:0>#StepLine:0
        matchTokenAt_7(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.startRule(context, RuleType.DataTable);
            this.build(context, token);
            return 8;
          }
          if (this.match_DocStringSeparator(context, token)) {
            this.startRule(context, RuleType.DocString);
            this.build(context, token);
            return 41;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 7;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 7;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 7;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 7;
        }
        // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTable:0>#TableRow:0
        matchTokenAt_8(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.build(context, token);
            return 8;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 7;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 8;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 8;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 8;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:0>Tags:0>#TagLine:0
        matchTokenAt_9(token, context) {
          if (this.match_TagLine(context, token)) {
            this.build(context, token);
            return 9;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 9;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 9;
          }
          token.detach();
          const expectedTokens = ["#TagLine", "#ScenarioLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 9;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:0>#ScenarioLine:0
        matchTokenAt_10(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 10;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 11;
          }
          if (this.match_StepLine(context, token)) {
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 12;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 11;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 10;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_11(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 11;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 12;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 11;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 11;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:0>#StepLine:0
        matchTokenAt_12(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.startRule(context, RuleType.DataTable);
            this.build(context, token);
            return 13;
          }
          if (this.match_DocStringSeparator(context, token)) {
            this.startRule(context, RuleType.DocString);
            this.build(context, token);
            return 39;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 12;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 12;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 12;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 12;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTable:0>#TableRow:0
        matchTokenAt_13(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.build(context, token);
            return 13;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 12;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 13;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 13;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 13;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:0>Tags:0>#TagLine:0
        matchTokenAt_14(token, context) {
          if (this.match_TagLine(context, token)) {
            this.build(context, token);
            return 14;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 14;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 14;
          }
          token.detach();
          const expectedTokens = ["#TagLine", "#ExamplesLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 14;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:0>#ExamplesLine:0
        matchTokenAt_15(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 15;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 16;
          }
          if (this.match_TableRow(context, token)) {
            this.startRule(context, RuleType.ExamplesTable);
            this.build(context, token);
            return 17;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 16;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 15;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_16(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 16;
          }
          if (this.match_TableRow(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesTable);
            this.build(context, token);
            return 17;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 16;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 16;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:2>ExamplesTable:0>#TableRow:0
        matchTokenAt_17(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.build(context, token);
            return 17;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 17;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 17;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 17;
        }
        // GherkinDocument:0>Feature:3>Rule:0>RuleHeader:0>Tags:0>#TagLine:0
        matchTokenAt_18(token, context) {
          if (this.match_TagLine(context, token)) {
            this.build(context, token);
            return 18;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 18;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 18;
          }
          token.detach();
          const expectedTokens = ["#TagLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 18;
        }
        // GherkinDocument:0>Feature:3>Rule:0>RuleHeader:1>#RuleLine:0
        matchTokenAt_19(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 20;
          }
          if (this.match_BackgroundLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Background);
            this.build(context, token);
            return 21;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 20;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 19;
        }
        // GherkinDocument:0>Feature:3>Rule:0>RuleHeader:2>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_20(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 20;
          }
          if (this.match_BackgroundLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Background);
            this.build(context, token);
            return 21;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 20;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 20;
        }
        // GherkinDocument:0>Feature:3>Rule:1>Background:0>#BackgroundLine:0
        matchTokenAt_21(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 21;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 22;
          }
          if (this.match_StepLine(context, token)) {
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 23;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 22;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 21;
        }
        // GherkinDocument:0>Feature:3>Rule:1>Background:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_22(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 22;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 23;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 22;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 22;
        }
        // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:0>#StepLine:0
        matchTokenAt_23(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.startRule(context, RuleType.DataTable);
            this.build(context, token);
            return 24;
          }
          if (this.match_DocStringSeparator(context, token)) {
            this.startRule(context, RuleType.DocString);
            this.build(context, token);
            return 37;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 23;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 23;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 23;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 23;
        }
        // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTable:0>#TableRow:0
        matchTokenAt_24(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.build(context, token);
            return 24;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 23;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 24;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 24;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 24;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:0>Tags:0>#TagLine:0
        matchTokenAt_25(token, context) {
          if (this.match_TagLine(context, token)) {
            this.build(context, token);
            return 25;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 25;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 25;
          }
          token.detach();
          const expectedTokens = ["#TagLine", "#ScenarioLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 25;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:0>#ScenarioLine:0
        matchTokenAt_26(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 26;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 27;
          }
          if (this.match_StepLine(context, token)) {
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 28;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 27;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 26;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_27(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 27;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 28;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 27;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 27;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:0>#StepLine:0
        matchTokenAt_28(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.startRule(context, RuleType.DataTable);
            this.build(context, token);
            return 29;
          }
          if (this.match_DocStringSeparator(context, token)) {
            this.startRule(context, RuleType.DocString);
            this.build(context, token);
            return 35;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 28;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 28;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 28;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 28;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTable:0>#TableRow:0
        matchTokenAt_29(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.build(context, token);
            return 29;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 28;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 29;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 29;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 29;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:0>Tags:0>#TagLine:0
        matchTokenAt_30(token, context) {
          if (this.match_TagLine(context, token)) {
            this.build(context, token);
            return 30;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 30;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 30;
          }
          token.detach();
          const expectedTokens = ["#TagLine", "#ExamplesLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 30;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:0>#ExamplesLine:0
        matchTokenAt_31(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 31;
          }
          if (this.match_Comment(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 32;
          }
          if (this.match_TableRow(context, token)) {
            this.startRule(context, RuleType.ExamplesTable);
            this.build(context, token);
            return 33;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.startRule(context, RuleType.Description);
            this.build(context, token);
            return 32;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Empty", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 31;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
        matchTokenAt_32(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 32;
          }
          if (this.match_TableRow(context, token)) {
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesTable);
            this.build(context, token);
            return 33;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 32;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 32;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:2>ExamplesTable:0>#TableRow:0
        matchTokenAt_33(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_TableRow(context, token)) {
            this.build(context, token);
            return 33;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 33;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 33;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 33;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocString:0>#DocStringSeparator:0
        matchTokenAt_35(token, context) {
          if (this.match_DocStringSeparator(context, token)) {
            this.build(context, token);
            return 36;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 35;
          }
          token.detach();
          const expectedTokens = ["#DocStringSeparator", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 35;
        }
        // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocString:2>#DocStringSeparator:0
        matchTokenAt_36(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 28;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 30;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 31;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 36;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 36;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 36;
        }
        // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:1>DocString:0>#DocStringSeparator:0
        matchTokenAt_37(token, context) {
          if (this.match_DocStringSeparator(context, token)) {
            this.build(context, token);
            return 38;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 37;
          }
          token.detach();
          const expectedTokens = ["#DocStringSeparator", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 37;
        }
        // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:1>DocString:2>#DocStringSeparator:0
        matchTokenAt_38(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 23;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 25;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 26;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 38;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 38;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 38;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocString:0>#DocStringSeparator:0
        matchTokenAt_39(token, context) {
          if (this.match_DocStringSeparator(context, token)) {
            this.build(context, token);
            return 40;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 39;
          }
          token.detach();
          const expectedTokens = ["#DocStringSeparator", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 39;
        }
        // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocString:2>#DocStringSeparator:0
        matchTokenAt_40(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 12;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_1(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ExamplesDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 14;
            }
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ExamplesLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ExamplesDefinition);
            this.startRule(context, RuleType.Examples);
            this.build(context, token);
            return 15;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 40;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 40;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 40;
        }
        // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:1>DocString:0>#DocStringSeparator:0
        matchTokenAt_41(token, context) {
          if (this.match_DocStringSeparator(context, token)) {
            this.build(context, token);
            return 42;
          }
          if (this.match_Other(context, token)) {
            this.build(context, token);
            return 41;
          }
          token.detach();
          const expectedTokens = ["#DocStringSeparator", "#Other"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 41;
        }
        // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:1>DocString:2>#DocStringSeparator:0
        matchTokenAt_42(token, context) {
          if (this.match_EOF(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.build(context, token);
            return 34;
          }
          if (this.match_StepLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Step);
            this.build(context, token);
            return 7;
          }
          if (this.match_TagLine(context, token)) {
            if (this.lookahead_0(context, token)) {
              this.endRule(context);
              this.endRule(context);
              this.endRule(context);
              this.startRule(context, RuleType.ScenarioDefinition);
              this.startRule(context, RuleType.Tags);
              this.build(context, token);
              return 9;
            }
          }
          if (this.match_TagLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.startRule(context, RuleType.Tags);
            this.build(context, token);
            return 18;
          }
          if (this.match_ScenarioLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.ScenarioDefinition);
            this.startRule(context, RuleType.Scenario);
            this.build(context, token);
            return 10;
          }
          if (this.match_RuleLine(context, token)) {
            this.endRule(context);
            this.endRule(context);
            this.endRule(context);
            this.startRule(context, RuleType.Rule);
            this.startRule(context, RuleType.RuleHeader);
            this.build(context, token);
            return 19;
          }
          if (this.match_Comment(context, token)) {
            this.build(context, token);
            return 42;
          }
          if (this.match_Empty(context, token)) {
            this.build(context, token);
            return 42;
          }
          token.detach();
          const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
          const error = token.isEof ? TokenExceptions_1.UnexpectedEOFException.create(token, expectedTokens) : TokenExceptions_1.UnexpectedTokenException.create(token, expectedTokens);
          if (this.stopAtFirstError)
            throw error;
          this.addError(context, error);
          return 42;
        }
        match_EOF(context, token) {
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_EOF(token));
        }
        match_Empty(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_Empty(token));
        }
        match_Comment(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_Comment(token));
        }
        match_TagLine(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_TagLine(token));
        }
        match_FeatureLine(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_FeatureLine(token));
        }
        match_RuleLine(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_RuleLine(token));
        }
        match_BackgroundLine(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_BackgroundLine(token));
        }
        match_ScenarioLine(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_ScenarioLine(token));
        }
        match_ExamplesLine(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_ExamplesLine(token));
        }
        match_StepLine(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_StepLine(token));
        }
        match_DocStringSeparator(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_DocStringSeparator(token));
        }
        match_TableRow(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_TableRow(token));
        }
        match_Language(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_Language(token));
        }
        match_Other(context, token) {
          if (token.isEof)
            return false;
          return this.handleExternalError(context, false, () => this.tokenMatcher.match_Other(token));
        }
        lookahead_0(context, currentToken) {
          currentToken.detach();
          let token;
          const queue = [];
          let match = false;
          do {
            token = this.readToken(this.context);
            token.detach();
            queue.push(token);
            if (this.match_ScenarioLine(context, token)) {
              match = true;
              break;
            }
          } while (this.match_Empty(context, token) || this.match_Comment(context, token) || this.match_TagLine(context, token));
          context.tokenQueue = context.tokenQueue.concat(queue);
          return match;
        }
        lookahead_1(context, currentToken) {
          currentToken.detach();
          let token;
          const queue = [];
          let match = false;
          do {
            token = this.readToken(this.context);
            token.detach();
            queue.push(token);
            if (this.match_ExamplesLine(context, token)) {
              match = true;
              break;
            }
          } while (this.match_Empty(context, token) || this.match_Comment(context, token) || this.match_TagLine(context, token));
          context.tokenQueue = context.tokenQueue.concat(queue);
          return match;
        }
      };
      exports.default = Parser2;
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/gherkin-languages.json
  var require_gherkin_languages = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/gherkin-languages.json"(exports, module) {
      module.exports = {
        af: {
          and: [
            "* ",
            "En "
          ],
          background: [
            "Agtergrond"
          ],
          but: [
            "* ",
            "Maar "
          ],
          examples: [
            "Voorbeelde"
          ],
          feature: [
            "Funksie",
            "Besigheid Behoefte",
            "Vermo\xEB"
          ],
          given: [
            "* ",
            "Gegewe "
          ],
          name: "Afrikaans",
          native: "Afrikaans",
          rule: [
            "Regel"
          ],
          scenario: [
            "Voorbeeld",
            "Situasie"
          ],
          scenarioOutline: [
            "Situasie Uiteensetting"
          ],
          then: [
            "* ",
            "Dan "
          ],
          when: [
            "* ",
            "Wanneer "
          ]
        },
        am: {
          and: [
            "* ",
            "\u0535\u057E "
          ],
          background: [
            "\u053F\u0578\u0576\u057F\u0565\u0584\u057D\u057F"
          ],
          but: [
            "* ",
            "\u0532\u0561\u0575\u0581 "
          ],
          examples: [
            "\u0555\u0580\u056B\u0576\u0561\u056F\u0576\u0565\u0580"
          ],
          feature: [
            "\u0556\u0578\u0582\u0576\u056F\u0581\u056B\u0578\u0576\u0561\u056C\u0578\u0582\u0569\u0575\u0578\u0582\u0576",
            "\u0540\u0561\u057F\u056F\u0578\u0582\u0569\u0575\u0578\u0582\u0576"
          ],
          given: [
            "* ",
            "\u0534\u056B\u0581\u0578\u0582\u0584 "
          ],
          name: "Armenian",
          native: "\u0570\u0561\u0575\u0565\u0580\u0565\u0576",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0555\u0580\u056B\u0576\u0561\u056F",
            "\u054D\u0581\u0565\u0576\u0561\u0580"
          ],
          scenarioOutline: [
            "\u054D\u0581\u0565\u0576\u0561\u0580\u056B \u056F\u0561\u057C\u0578\u0582\u0581\u057E\u0561\u0581\u0584\u0568"
          ],
          then: [
            "* ",
            "\u0531\u057A\u0561 "
          ],
          when: [
            "* ",
            "\u0535\u0569\u0565 ",
            "\u0535\u0580\u0562 "
          ]
        },
        an: {
          and: [
            "* ",
            "Y ",
            "E "
          ],
          background: [
            "Antecedents"
          ],
          but: [
            "* ",
            "Pero "
          ],
          examples: [
            "Eixemplos"
          ],
          feature: [
            "Caracteristica"
          ],
          given: [
            "* ",
            "Dau ",
            "Dada ",
            "Daus ",
            "Dadas "
          ],
          name: "Aragonese",
          native: "Aragon\xE9s",
          rule: [
            "Rule"
          ],
          scenario: [
            "Eixemplo",
            "Caso"
          ],
          scenarioOutline: [
            "Esquema del caso"
          ],
          then: [
            "* ",
            "Alavez ",
            "Allora ",
            "Antonces "
          ],
          when: [
            "* ",
            "Cuan "
          ]
        },
        ar: {
          and: [
            "* ",
            "\u0648 "
          ],
          background: [
            "\u0627\u0644\u062E\u0644\u0641\u064A\u0629"
          ],
          but: [
            "* ",
            "\u0644\u0643\u0646 "
          ],
          examples: [
            "\u0627\u0645\u062B\u0644\u0629"
          ],
          feature: [
            "\u062E\u0627\u0635\u064A\u0629"
          ],
          given: [
            "* ",
            "\u0628\u0641\u0631\u0636 "
          ],
          name: "Arabic",
          native: "\u0627\u0644\u0639\u0631\u0628\u064A\u0629",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0645\u062B\u0627\u0644",
            "\u0633\u064A\u0646\u0627\u0631\u064A\u0648"
          ],
          scenarioOutline: [
            "\u0633\u064A\u0646\u0627\u0631\u064A\u0648 \u0645\u062E\u0637\u0637"
          ],
          then: [
            "* ",
            "\u0627\u0630\u0627\u064B ",
            "\u062B\u0645 "
          ],
          when: [
            "* ",
            "\u0645\u062A\u0649 ",
            "\u0639\u0646\u062F\u0645\u0627 "
          ]
        },
        ast: {
          and: [
            "* ",
            "Y ",
            "Ya "
          ],
          background: [
            "Antecedentes"
          ],
          but: [
            "* ",
            "Peru "
          ],
          examples: [
            "Exemplos"
          ],
          feature: [
            "Carauter\xEDstica"
          ],
          given: [
            "* ",
            "D\xE1u ",
            "Dada ",
            "Daos ",
            "Daes "
          ],
          name: "Asturian",
          native: "asturianu",
          rule: [
            "Rule"
          ],
          scenario: [
            "Exemplo",
            "Casu"
          ],
          scenarioOutline: [
            "Esbozu del casu"
          ],
          then: [
            "* ",
            "Ent\xF3s "
          ],
          when: [
            "* ",
            "Cuando "
          ]
        },
        az: {
          and: [
            "* ",
            "V\u0259 ",
            "H\u0259m "
          ],
          background: [
            "Ke\xE7mi\u015F",
            "Kontekst"
          ],
          but: [
            "* ",
            "Amma ",
            "Ancaq "
          ],
          examples: [
            "N\xFCmun\u0259l\u0259r"
          ],
          feature: [
            "\xD6z\u0259llik"
          ],
          given: [
            "* ",
            "Tutaq ki ",
            "Verilir "
          ],
          name: "Azerbaijani",
          native: "Az\u0259rbaycanca",
          rule: [
            "Rule"
          ],
          scenario: [
            "N\xFCmun\u0259",
            "Ssenari"
          ],
          scenarioOutline: [
            "Ssenarinin strukturu"
          ],
          then: [
            "* ",
            "O halda "
          ],
          when: [
            "* ",
            "\u018Fg\u0259r ",
            "N\u0259 vaxt ki "
          ]
        },
        be: {
          and: [
            "* ",
            "I ",
            "\u0414\u044B ",
            "\u0422\u0430\u043A\u0441\u0430\u043C\u0430 "
          ],
          background: [
            "\u041A\u0430\u043D\u0442\u044D\u043A\u0441\u0442"
          ],
          but: [
            "* ",
            "\u0410\u043B\u0435 ",
            "\u0406\u043D\u0430\u043A\u0448 "
          ],
          examples: [
            "\u041F\u0440\u044B\u043A\u043B\u0430\u0434\u044B"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446\u044B\u044F\u043D\u0430\u043B\u044C\u043D\u0430\u0441\u0446\u044C",
            "\u0424\u0456\u0447\u0430"
          ],
          given: [
            "* ",
            "\u041D\u044F\u0445\u0430\u0439 ",
            "\u0414\u0430\u0434\u0437\u0435\u043D\u0430 "
          ],
          name: "Belarusian",
          native: "\u0411\u0435\u043B\u0430\u0440\u0443\u0441\u043A\u0430\u044F",
          rule: [
            "\u041F\u0440\u0430\u0432\u0456\u043B\u044B"
          ],
          scenario: [
            "\u0421\u0446\u044D\u043D\u0430\u0440\u044B\u0439",
            "C\u0446\u044D\u043D\u0430\u0440"
          ],
          scenarioOutline: [
            "\u0428\u0430\u0431\u043B\u043E\u043D \u0441\u0446\u044D\u043D\u0430\u0440\u044B\u044F",
            "\u0423\u0437\u043E\u0440 \u0441\u0446\u044D\u043D\u0430\u0440\u0430"
          ],
          then: [
            "* ",
            "\u0422\u0430\u0434\u044B "
          ],
          when: [
            "* ",
            "\u041A\u0430\u043B\u0456 "
          ]
        },
        bg: {
          and: [
            "* ",
            "\u0418 "
          ],
          background: [
            "\u041F\u0440\u0435\u0434\u0438\u0441\u0442\u043E\u0440\u0438\u044F"
          ],
          but: [
            "* ",
            "\u041D\u043E "
          ],
          examples: [
            "\u041F\u0440\u0438\u043C\u0435\u0440\u0438"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u043D\u043E\u0441\u0442"
          ],
          given: [
            "* ",
            "\u0414\u0430\u0434\u0435\u043D\u043E "
          ],
          name: "Bulgarian",
          native: "\u0431\u044A\u043B\u0433\u0430\u0440\u0441\u043A\u0438",
          rule: [
            "\u041F\u0440\u0430\u0432\u0438\u043B\u043E"
          ],
          scenario: [
            "\u041F\u0440\u0438\u043C\u0435\u0440",
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
          ],
          scenarioOutline: [
            "\u0420\u0430\u043C\u043A\u0430 \u043D\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
          ],
          then: [
            "* ",
            "\u0422\u043E "
          ],
          when: [
            "* ",
            "\u041A\u043E\u0433\u0430\u0442\u043E "
          ]
        },
        bm: {
          and: [
            "* ",
            "Dan "
          ],
          background: [
            "Latar Belakang"
          ],
          but: [
            "* ",
            "Tetapi ",
            "Tapi "
          ],
          examples: [
            "Contoh"
          ],
          feature: [
            "Fungsi"
          ],
          given: [
            "* ",
            "Diberi ",
            "Bagi "
          ],
          name: "Malay",
          native: "Bahasa Melayu",
          rule: [
            "Rule"
          ],
          scenario: [
            "Senario",
            "Situasi",
            "Keadaan"
          ],
          scenarioOutline: [
            "Kerangka Senario",
            "Kerangka Situasi",
            "Kerangka Keadaan",
            "Garis Panduan Senario"
          ],
          then: [
            "* ",
            "Maka ",
            "Kemudian "
          ],
          when: [
            "* ",
            "Apabila "
          ]
        },
        bs: {
          and: [
            "* ",
            "I ",
            "A "
          ],
          background: [
            "Pozadina"
          ],
          but: [
            "* ",
            "Ali "
          ],
          examples: [
            "Primjeri"
          ],
          feature: [
            "Karakteristika"
          ],
          given: [
            "* ",
            "Dato "
          ],
          name: "Bosnian",
          native: "Bosanski",
          rule: [
            "Rule"
          ],
          scenario: [
            "Primjer",
            "Scenariju",
            "Scenario"
          ],
          scenarioOutline: [
            "Scenariju-obris",
            "Scenario-outline"
          ],
          then: [
            "* ",
            "Zatim "
          ],
          when: [
            "* ",
            "Kada "
          ]
        },
        ca: {
          and: [
            "* ",
            "I "
          ],
          background: [
            "Rerefons",
            "Antecedents"
          ],
          but: [
            "* ",
            "Per\xF2 "
          ],
          examples: [
            "Exemples"
          ],
          feature: [
            "Caracter\xEDstica",
            "Funcionalitat"
          ],
          given: [
            "* ",
            "Donat ",
            "Donada ",
            "At\xE8s ",
            "Atesa "
          ],
          name: "Catalan",
          native: "catal\xE0",
          rule: [
            "Rule"
          ],
          scenario: [
            "Exemple",
            "Escenari"
          ],
          scenarioOutline: [
            "Esquema de l'escenari"
          ],
          then: [
            "* ",
            "Aleshores ",
            "Cal "
          ],
          when: [
            "* ",
            "Quan "
          ]
        },
        cs: {
          and: [
            "* ",
            "A tak\xE9 ",
            "A "
          ],
          background: [
            "Pozad\xED",
            "Kontext"
          ],
          but: [
            "* ",
            "Ale "
          ],
          examples: [
            "P\u0159\xEDklady"
          ],
          feature: [
            "Po\u017Eadavek"
          ],
          given: [
            "* ",
            "Pokud ",
            "Za p\u0159edpokladu "
          ],
          name: "Czech",
          native: "\u010Cesky",
          rule: [
            "Pravidlo"
          ],
          scenario: [
            "P\u0159\xEDklad",
            "Sc\xE9n\xE1\u0159"
          ],
          scenarioOutline: [
            "N\xE1\u010Drt Sc\xE9n\xE1\u0159e",
            "Osnova sc\xE9n\xE1\u0159e"
          ],
          then: [
            "* ",
            "Pak "
          ],
          when: [
            "* ",
            "Kdy\u017E "
          ]
        },
        "cy-GB": {
          and: [
            "* ",
            "A "
          ],
          background: [
            "Cefndir"
          ],
          but: [
            "* ",
            "Ond "
          ],
          examples: [
            "Enghreifftiau"
          ],
          feature: [
            "Arwedd"
          ],
          given: [
            "* ",
            "Anrhegedig a "
          ],
          name: "Welsh",
          native: "Cymraeg",
          rule: [
            "Rule"
          ],
          scenario: [
            "Enghraifft",
            "Scenario"
          ],
          scenarioOutline: [
            "Scenario Amlinellol"
          ],
          then: [
            "* ",
            "Yna "
          ],
          when: [
            "* ",
            "Pryd "
          ]
        },
        da: {
          and: [
            "* ",
            "Og "
          ],
          background: [
            "Baggrund"
          ],
          but: [
            "* ",
            "Men "
          ],
          examples: [
            "Eksempler"
          ],
          feature: [
            "Egenskab"
          ],
          given: [
            "* ",
            "Givet "
          ],
          name: "Danish",
          native: "dansk",
          rule: [
            "Regel"
          ],
          scenario: [
            "Eksempel",
            "Scenarie"
          ],
          scenarioOutline: [
            "Abstrakt Scenario"
          ],
          then: [
            "* ",
            "S\xE5 "
          ],
          when: [
            "* ",
            "N\xE5r "
          ]
        },
        de: {
          and: [
            "* ",
            "Und "
          ],
          background: [
            "Grundlage",
            "Hintergrund",
            "Voraussetzungen",
            "Vorbedingungen"
          ],
          but: [
            "* ",
            "Aber "
          ],
          examples: [
            "Beispiele"
          ],
          feature: [
            "Funktionalit\xE4t",
            "Funktion"
          ],
          given: [
            "* ",
            "Angenommen ",
            "Gegeben sei ",
            "Gegeben seien "
          ],
          name: "German",
          native: "Deutsch",
          rule: [
            "Rule",
            "Regel"
          ],
          scenario: [
            "Beispiel",
            "Szenario"
          ],
          scenarioOutline: [
            "Szenariogrundriss",
            "Szenarien"
          ],
          then: [
            "* ",
            "Dann "
          ],
          when: [
            "* ",
            "Wenn "
          ]
        },
        el: {
          and: [
            "* ",
            "\u039A\u03B1\u03B9 "
          ],
          background: [
            "\u03A5\u03C0\u03CC\u03B2\u03B1\u03B8\u03C1\u03BF"
          ],
          but: [
            "* ",
            "\u0391\u03BB\u03BB\u03AC "
          ],
          examples: [
            "\u03A0\u03B1\u03C1\u03B1\u03B4\u03B5\u03AF\u03B3\u03BC\u03B1\u03C4\u03B1",
            "\u03A3\u03B5\u03BD\u03AC\u03C1\u03B9\u03B1"
          ],
          feature: [
            "\u0394\u03C5\u03BD\u03B1\u03C4\u03CC\u03C4\u03B7\u03C4\u03B1",
            "\u039B\u03B5\u03B9\u03C4\u03BF\u03C5\u03C1\u03B3\u03AF\u03B1"
          ],
          given: [
            "* ",
            "\u0394\u03B5\u03B4\u03BF\u03BC\u03AD\u03BD\u03BF\u03C5 "
          ],
          name: "Greek",
          native: "\u0395\u03BB\u03BB\u03B7\u03BD\u03B9\u03BA\u03AC",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u03A0\u03B1\u03C1\u03AC\u03B4\u03B5\u03B9\u03B3\u03BC\u03B1",
            "\u03A3\u03B5\u03BD\u03AC\u03C1\u03B9\u03BF"
          ],
          scenarioOutline: [
            "\u03A0\u03B5\u03C1\u03B9\u03B3\u03C1\u03B1\u03C6\u03AE \u03A3\u03B5\u03BD\u03B1\u03C1\u03AF\u03BF\u03C5",
            "\u03A0\u03B5\u03C1\u03AF\u03B3\u03C1\u03B1\u03BC\u03BC\u03B1 \u03A3\u03B5\u03BD\u03B1\u03C1\u03AF\u03BF\u03C5"
          ],
          then: [
            "* ",
            "\u03A4\u03CC\u03C4\u03B5 "
          ],
          when: [
            "* ",
            "\u038C\u03C4\u03B1\u03BD "
          ]
        },
        em: {
          and: [
            "* ",
            "\u{1F602}"
          ],
          background: [
            "\u{1F4A4}"
          ],
          but: [
            "* ",
            "\u{1F614}"
          ],
          examples: [
            "\u{1F4D3}"
          ],
          feature: [
            "\u{1F4DA}"
          ],
          given: [
            "* ",
            "\u{1F610}"
          ],
          name: "Emoji",
          native: "\u{1F600}",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u{1F952}",
            "\u{1F4D5}"
          ],
          scenarioOutline: [
            "\u{1F4D6}"
          ],
          then: [
            "* ",
            "\u{1F64F}"
          ],
          when: [
            "* ",
            "\u{1F3AC}"
          ]
        },
        en: {
          and: [
            "* ",
            "And "
          ],
          background: [
            "Background"
          ],
          but: [
            "* ",
            "But "
          ],
          examples: [
            "Examples",
            "Scenarios"
          ],
          feature: [
            "Feature",
            "Business Need",
            "Ability"
          ],
          given: [
            "* ",
            "Given "
          ],
          name: "English",
          native: "English",
          rule: [
            "Rule"
          ],
          scenario: [
            "Example",
            "Scenario"
          ],
          scenarioOutline: [
            "Scenario Outline",
            "Scenario Template"
          ],
          then: [
            "* ",
            "Then "
          ],
          when: [
            "* ",
            "When "
          ]
        },
        "en-Scouse": {
          and: [
            "* ",
            "An "
          ],
          background: [
            "Dis is what went down"
          ],
          but: [
            "* ",
            "Buh "
          ],
          examples: [
            "Examples"
          ],
          feature: [
            "Feature"
          ],
          given: [
            "* ",
            "Givun ",
            "Youse know when youse got "
          ],
          name: "Scouse",
          native: "Scouse",
          rule: [
            "Rule"
          ],
          scenario: [
            "The thing of it is"
          ],
          scenarioOutline: [
            "Wharrimean is"
          ],
          then: [
            "* ",
            "Dun ",
            "Den youse gotta "
          ],
          when: [
            "* ",
            "Wun ",
            "Youse know like when "
          ]
        },
        "en-au": {
          and: [
            "* ",
            "Too right "
          ],
          background: [
            "First off"
          ],
          but: [
            "* ",
            "Yeah nah "
          ],
          examples: [
            "You'll wanna"
          ],
          feature: [
            "Pretty much"
          ],
          given: [
            "* ",
            "Y'know "
          ],
          name: "Australian",
          native: "Australian",
          rule: [
            "Rule"
          ],
          scenario: [
            "Awww, look mate"
          ],
          scenarioOutline: [
            "Reckon it's like"
          ],
          then: [
            "* ",
            "But at the end of the day I reckon "
          ],
          when: [
            "* ",
            "It's just unbelievable "
          ]
        },
        "en-lol": {
          and: [
            "* ",
            "AN "
          ],
          background: [
            "B4"
          ],
          but: [
            "* ",
            "BUT "
          ],
          examples: [
            "EXAMPLZ"
          ],
          feature: [
            "OH HAI"
          ],
          given: [
            "* ",
            "I CAN HAZ "
          ],
          name: "LOLCAT",
          native: "LOLCAT",
          rule: [
            "Rule"
          ],
          scenario: [
            "MISHUN"
          ],
          scenarioOutline: [
            "MISHUN SRSLY"
          ],
          then: [
            "* ",
            "DEN "
          ],
          when: [
            "* ",
            "WEN "
          ]
        },
        "en-old": {
          and: [
            "* ",
            "Ond ",
            "7 "
          ],
          background: [
            "Aer",
            "\xC6r"
          ],
          but: [
            "* ",
            "Ac "
          ],
          examples: [
            "Se the",
            "Se \xFEe",
            "Se \xF0e"
          ],
          feature: [
            "Hwaet",
            "Hw\xE6t"
          ],
          given: [
            "* ",
            "Thurh ",
            "\xDEurh ",
            "\xD0urh "
          ],
          name: "Old English",
          native: "Englisc",
          rule: [
            "Rule"
          ],
          scenario: [
            "Swa"
          ],
          scenarioOutline: [
            "Swa hwaer swa",
            "Swa hw\xE6r swa"
          ],
          then: [
            "* ",
            "Tha ",
            "\xDEa ",
            "\xD0a ",
            "Tha the ",
            "\xDEa \xFEe ",
            "\xD0a \xF0e "
          ],
          when: [
            "* ",
            "B\xE6\xFEsealf ",
            "B\xE6\xFEsealfa ",
            "B\xE6\xFEsealfe ",
            "Ciric\xE6w ",
            "Ciric\xE6we ",
            "Ciric\xE6wa "
          ]
        },
        "en-pirate": {
          and: [
            "* ",
            "Aye "
          ],
          background: [
            "Yo-ho-ho"
          ],
          but: [
            "* ",
            "Avast! "
          ],
          examples: [
            "Dead men tell no tales"
          ],
          feature: [
            "Ahoy matey!"
          ],
          given: [
            "* ",
            "Gangway! "
          ],
          name: "Pirate",
          native: "Pirate",
          rule: [
            "Rule"
          ],
          scenario: [
            "Heave to"
          ],
          scenarioOutline: [
            "Shiver me timbers"
          ],
          then: [
            "* ",
            "Let go and haul "
          ],
          when: [
            "* ",
            "Blimey! "
          ]
        },
        "en-tx": {
          and: [
            "Come hell or high water "
          ],
          background: [
            "Lemme tell y'all a story"
          ],
          but: [
            "Well now hold on, I'll you what "
          ],
          examples: [
            "Now that's a story longer than a cattle drive in July"
          ],
          feature: [
            "This ain\u2019t my first rodeo",
            "All gussied up"
          ],
          given: [
            "Fixin' to ",
            "All git out "
          ],
          name: "Texas",
          native: "Texas",
          rule: [
            "Rule "
          ],
          scenario: [
            "All hat and no cattle"
          ],
          scenarioOutline: [
            "Serious as a snake bite",
            "Busy as a hound in flea season"
          ],
          then: [
            "There\u2019s no tree but bears some fruit "
          ],
          when: [
            "Quick out of the chute "
          ]
        },
        eo: {
          and: [
            "* ",
            "Kaj "
          ],
          background: [
            "Fono"
          ],
          but: [
            "* ",
            "Sed "
          ],
          examples: [
            "Ekzemploj"
          ],
          feature: [
            "Trajto"
          ],
          given: [
            "* ",
            "Donita\u0135o ",
            "Komence "
          ],
          name: "Esperanto",
          native: "Esperanto",
          rule: [
            "Regulo"
          ],
          scenario: [
            "Ekzemplo",
            "Scenaro",
            "Kazo"
          ],
          scenarioOutline: [
            "Konturo de la scenaro",
            "Skizo",
            "Kazo-skizo"
          ],
          then: [
            "* ",
            "Do "
          ],
          when: [
            "* ",
            "Se "
          ]
        },
        es: {
          and: [
            "* ",
            "Y ",
            "E "
          ],
          background: [
            "Antecedentes"
          ],
          but: [
            "* ",
            "Pero "
          ],
          examples: [
            "Ejemplos"
          ],
          feature: [
            "Caracter\xEDstica",
            "Necesidad del negocio",
            "Requisito"
          ],
          given: [
            "* ",
            "Dado ",
            "Dada ",
            "Dados ",
            "Dadas "
          ],
          name: "Spanish",
          native: "espa\xF1ol",
          rule: [
            "Regla",
            "Regla de negocio"
          ],
          scenario: [
            "Ejemplo",
            "Escenario"
          ],
          scenarioOutline: [
            "Esquema del escenario"
          ],
          then: [
            "* ",
            "Entonces "
          ],
          when: [
            "* ",
            "Cuando "
          ]
        },
        et: {
          and: [
            "* ",
            "Ja "
          ],
          background: [
            "Taust"
          ],
          but: [
            "* ",
            "Kuid "
          ],
          examples: [
            "Juhtumid"
          ],
          feature: [
            "Omadus"
          ],
          given: [
            "* ",
            "Eeldades "
          ],
          name: "Estonian",
          native: "eesti keel",
          rule: [
            "Reegel"
          ],
          scenario: [
            "Juhtum",
            "Stsenaarium"
          ],
          scenarioOutline: [
            "Raamjuhtum",
            "Raamstsenaarium"
          ],
          then: [
            "* ",
            "Siis "
          ],
          when: [
            "* ",
            "Kui "
          ]
        },
        fa: {
          and: [
            "* ",
            "\u0648 "
          ],
          background: [
            "\u0632\u0645\u06CC\u0646\u0647"
          ],
          but: [
            "* ",
            "\u0627\u0645\u0627 "
          ],
          examples: [
            "\u0646\u0645\u0648\u0646\u0647 \u0647\u0627"
          ],
          feature: [
            "\u0648\u0650\u06CC\u0698\u06AF\u06CC"
          ],
          given: [
            "* ",
            "\u0628\u0627 \u0641\u0631\u0636 "
          ],
          name: "Persian",
          native: "\u0641\u0627\u0631\u0633\u06CC",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0645\u062B\u0627\u0644",
            "\u0633\u0646\u0627\u0631\u06CC\u0648"
          ],
          scenarioOutline: [
            "\u0627\u0644\u06AF\u0648\u06CC \u0633\u0646\u0627\u0631\u06CC\u0648"
          ],
          then: [
            "* ",
            "\u0622\u0646\u06AF\u0627\u0647 "
          ],
          when: [
            "* ",
            "\u0647\u0646\u06AF\u0627\u0645\u06CC "
          ]
        },
        fi: {
          and: [
            "* ",
            "Ja "
          ],
          background: [
            "Tausta"
          ],
          but: [
            "* ",
            "Mutta "
          ],
          examples: [
            "Tapaukset"
          ],
          feature: [
            "Ominaisuus"
          ],
          given: [
            "* ",
            "Oletetaan "
          ],
          name: "Finnish",
          native: "suomi",
          rule: [
            "Rule"
          ],
          scenario: [
            "Tapaus"
          ],
          scenarioOutline: [
            "Tapausaihio"
          ],
          then: [
            "* ",
            "Niin "
          ],
          when: [
            "* ",
            "Kun "
          ]
        },
        fr: {
          and: [
            "* ",
            "Et que ",
            "Et qu'",
            "Et "
          ],
          background: [
            "Contexte"
          ],
          but: [
            "* ",
            "Mais que ",
            "Mais qu'",
            "Mais "
          ],
          examples: [
            "Exemples"
          ],
          feature: [
            "Fonctionnalit\xE9"
          ],
          given: [
            "* ",
            "Soit ",
            "Sachant que ",
            "Sachant qu'",
            "Sachant ",
            "Etant donn\xE9 que ",
            "Etant donn\xE9 qu'",
            "Etant donn\xE9 ",
            "Etant donn\xE9e ",
            "Etant donn\xE9s ",
            "Etant donn\xE9es ",
            "\xC9tant donn\xE9 que ",
            "\xC9tant donn\xE9 qu'",
            "\xC9tant donn\xE9 ",
            "\xC9tant donn\xE9e ",
            "\xC9tant donn\xE9s ",
            "\xC9tant donn\xE9es "
          ],
          name: "French",
          native: "fran\xE7ais",
          rule: [
            "R\xE8gle"
          ],
          scenario: [
            "Exemple",
            "Sc\xE9nario"
          ],
          scenarioOutline: [
            "Plan du sc\xE9nario",
            "Plan du Sc\xE9nario"
          ],
          then: [
            "* ",
            "Alors ",
            "Donc "
          ],
          when: [
            "* ",
            "Quand ",
            "Lorsque ",
            "Lorsqu'"
          ]
        },
        ga: {
          and: [
            "* ",
            "Agus "
          ],
          background: [
            "C\xFAlra"
          ],
          but: [
            "* ",
            "Ach "
          ],
          examples: [
            "Sampla\xED"
          ],
          feature: [
            "Gn\xE9"
          ],
          given: [
            "* ",
            "Cuir i gc\xE1s go ",
            "Cuir i gc\xE1s nach ",
            "Cuir i gc\xE1s gur ",
            "Cuir i gc\xE1s n\xE1r "
          ],
          name: "Irish",
          native: "Gaeilge",
          rule: [
            "Riail"
          ],
          scenario: [
            "Sampla",
            "C\xE1s"
          ],
          scenarioOutline: [
            "C\xE1s Achomair"
          ],
          then: [
            "* ",
            "Ansin "
          ],
          when: [
            "* ",
            "Nuair a ",
            "Nuair nach ",
            "Nuair ba ",
            "Nuair n\xE1r "
          ]
        },
        gj: {
          and: [
            "* ",
            "\u0A85\u0AA8\u0AC7 "
          ],
          background: [
            "\u0AAC\u0AC7\u0A95\u0A97\u0ACD\u0AB0\u0ABE\u0A89\u0AA8\u0ACD\u0AA1"
          ],
          but: [
            "* ",
            "\u0AAA\u0AA3 "
          ],
          examples: [
            "\u0A89\u0AA6\u0ABE\u0AB9\u0AB0\u0AA3\u0ACB"
          ],
          feature: [
            "\u0AB2\u0A95\u0ACD\u0AB7\u0AA3",
            "\u0AB5\u0ACD\u0AAF\u0ABE\u0AAA\u0ABE\u0AB0 \u0A9C\u0AB0\u0AC2\u0AB0",
            "\u0A95\u0ACD\u0AB7\u0AAE\u0AA4\u0ABE"
          ],
          given: [
            "* ",
            "\u0A86\u0AAA\u0AC7\u0AB2 \u0A9B\u0AC7 "
          ],
          name: "Gujarati",
          native: "\u0A97\u0AC1\u0A9C\u0AB0\u0ABE\u0AA4\u0AC0",
          rule: [
            "\u0AA8\u0ABF\u0AAF\u0AAE"
          ],
          scenario: [
            "\u0A89\u0AA6\u0ABE\u0AB9\u0AB0\u0AA3",
            "\u0AB8\u0ACD\u0AA5\u0ABF\u0AA4\u0ABF"
          ],
          scenarioOutline: [
            "\u0AAA\u0AB0\u0ABF\u0AA6\u0ACD\u0AA6\u0AB6\u0ACD\u0AAF \u0AB0\u0AC2\u0AAA\u0AB0\u0AC7\u0A96\u0ABE",
            "\u0AAA\u0AB0\u0ABF\u0AA6\u0ACD\u0AA6\u0AB6\u0ACD\u0AAF \u0AA2\u0ABE\u0A82\u0A9A\u0ACB"
          ],
          then: [
            "* ",
            "\u0AAA\u0A9B\u0AC0 "
          ],
          when: [
            "* ",
            "\u0A95\u0ACD\u0AAF\u0ABE\u0AB0\u0AC7 "
          ]
        },
        gl: {
          and: [
            "* ",
            "E "
          ],
          background: [
            "Contexto"
          ],
          but: [
            "* ",
            "Mais ",
            "Pero "
          ],
          examples: [
            "Exemplos"
          ],
          feature: [
            "Caracter\xEDstica"
          ],
          given: [
            "* ",
            "Dado ",
            "Dada ",
            "Dados ",
            "Dadas "
          ],
          name: "Galician",
          native: "galego",
          rule: [
            "Rule"
          ],
          scenario: [
            "Exemplo",
            "Escenario"
          ],
          scenarioOutline: [
            "Esbozo do escenario"
          ],
          then: [
            "* ",
            "Ent\xF3n ",
            "Logo "
          ],
          when: [
            "* ",
            "Cando "
          ]
        },
        he: {
          and: [
            "* ",
            "\u05D5\u05D2\u05DD "
          ],
          background: [
            "\u05E8\u05E7\u05E2"
          ],
          but: [
            "* ",
            "\u05D0\u05D1\u05DC "
          ],
          examples: [
            "\u05D3\u05D5\u05D2\u05DE\u05D0\u05D5\u05EA"
          ],
          feature: [
            "\u05EA\u05DB\u05D5\u05E0\u05D4"
          ],
          given: [
            "* ",
            "\u05D1\u05D4\u05D9\u05E0\u05EA\u05DF "
          ],
          name: "Hebrew",
          native: "\u05E2\u05D1\u05E8\u05D9\u05EA",
          rule: [
            "\u05DB\u05DC\u05DC"
          ],
          scenario: [
            "\u05D3\u05D5\u05D2\u05DE\u05D0",
            "\u05EA\u05E8\u05D7\u05D9\u05E9"
          ],
          scenarioOutline: [
            "\u05EA\u05D1\u05E0\u05D9\u05EA \u05EA\u05E8\u05D7\u05D9\u05E9"
          ],
          then: [
            "* ",
            "\u05D0\u05D6 ",
            "\u05D0\u05D6\u05D9 "
          ],
          when: [
            "* ",
            "\u05DB\u05D0\u05E9\u05E8 "
          ]
        },
        hi: {
          and: [
            "* ",
            "\u0914\u0930 ",
            "\u0924\u0925\u093E "
          ],
          background: [
            "\u092A\u0943\u0937\u094D\u0920\u092D\u0942\u092E\u093F"
          ],
          but: [
            "* ",
            "\u092A\u0930 ",
            "\u092A\u0930\u0928\u094D\u0924\u0941 ",
            "\u0915\u093F\u0928\u094D\u0924\u0941 "
          ],
          examples: [
            "\u0909\u0926\u093E\u0939\u0930\u0923"
          ],
          feature: [
            "\u0930\u0942\u092A \u0932\u0947\u0916"
          ],
          given: [
            "* ",
            "\u0905\u0917\u0930 ",
            "\u092F\u0926\u093F ",
            "\u091A\u0942\u0902\u0915\u093F "
          ],
          name: "Hindi",
          native: "\u0939\u093F\u0902\u0926\u0940",
          rule: [
            "\u0928\u093F\u092F\u092E"
          ],
          scenario: [
            "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F"
          ],
          scenarioOutline: [
            "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F \u0930\u0942\u092A\u0930\u0947\u0916\u093E"
          ],
          then: [
            "* ",
            "\u0924\u092C ",
            "\u0924\u0926\u093E "
          ],
          when: [
            "* ",
            "\u091C\u092C ",
            "\u0915\u0926\u093E "
          ]
        },
        hr: {
          and: [
            "* ",
            "I "
          ],
          background: [
            "Pozadina"
          ],
          but: [
            "* ",
            "Ali "
          ],
          examples: [
            "Primjeri",
            "Scenariji"
          ],
          feature: [
            "Osobina",
            "Mogu\u0107nost",
            "Mogucnost"
          ],
          given: [
            "* ",
            "Zadan ",
            "Zadani ",
            "Zadano ",
            "Ukoliko "
          ],
          name: "Croatian",
          native: "hrvatski",
          rule: [
            "Rule"
          ],
          scenario: [
            "Primjer",
            "Scenarij"
          ],
          scenarioOutline: [
            "Skica",
            "Koncept"
          ],
          then: [
            "* ",
            "Onda "
          ],
          when: [
            "* ",
            "Kada ",
            "Kad "
          ]
        },
        ht: {
          and: [
            "* ",
            "Ak ",
            "Epi ",
            "E "
          ],
          background: [
            "Kont\xE8ks",
            "Istorik"
          ],
          but: [
            "* ",
            "Men "
          ],
          examples: [
            "Egzanp"
          ],
          feature: [
            "Karakteristik",
            "Mak",
            "Fonksyonalite"
          ],
          given: [
            "* ",
            "Sipoze ",
            "Sipoze ke ",
            "Sipoze Ke "
          ],
          name: "Creole",
          native: "krey\xF2l",
          rule: [
            "Rule"
          ],
          scenario: [
            "Senaryo"
          ],
          scenarioOutline: [
            "Plan senaryo",
            "Plan Senaryo",
            "Senaryo deskripsyon",
            "Senaryo Deskripsyon",
            "Dyagram senaryo",
            "Dyagram Senaryo"
          ],
          then: [
            "* ",
            "L\xE8 sa a ",
            "Le sa a "
          ],
          when: [
            "* ",
            "L\xE8 ",
            "Le "
          ]
        },
        hu: {
          and: [
            "* ",
            "\xC9s "
          ],
          background: [
            "H\xE1tt\xE9r"
          ],
          but: [
            "* ",
            "De "
          ],
          examples: [
            "P\xE9ld\xE1k"
          ],
          feature: [
            "Jellemz\u0151"
          ],
          given: [
            "* ",
            "Amennyiben ",
            "Adott "
          ],
          name: "Hungarian",
          native: "magyar",
          rule: [
            "Szab\xE1ly"
          ],
          scenario: [
            "P\xE9lda",
            "Forgat\xF3k\xF6nyv"
          ],
          scenarioOutline: [
            "Forgat\xF3k\xF6nyv v\xE1zlat"
          ],
          then: [
            "* ",
            "Akkor "
          ],
          when: [
            "* ",
            "Majd ",
            "Ha ",
            "Amikor "
          ]
        },
        id: {
          and: [
            "* ",
            "Dan "
          ],
          background: [
            "Dasar",
            "Latar Belakang"
          ],
          but: [
            "* ",
            "Tapi ",
            "Tetapi "
          ],
          examples: [
            "Contoh",
            "Misal"
          ],
          feature: [
            "Fitur"
          ],
          given: [
            "* ",
            "Dengan ",
            "Diketahui ",
            "Diasumsikan ",
            "Bila ",
            "Jika "
          ],
          name: "Indonesian",
          native: "Bahasa Indonesia",
          rule: [
            "Rule",
            "Aturan"
          ],
          scenario: [
            "Skenario"
          ],
          scenarioOutline: [
            "Skenario konsep",
            "Garis-Besar Skenario"
          ],
          then: [
            "* ",
            "Maka ",
            "Kemudian "
          ],
          when: [
            "* ",
            "Ketika "
          ]
        },
        is: {
          and: [
            "* ",
            "Og "
          ],
          background: [
            "Bakgrunnur"
          ],
          but: [
            "* ",
            "En "
          ],
          examples: [
            "D\xE6mi",
            "Atbur\xF0ar\xE1sir"
          ],
          feature: [
            "Eiginleiki"
          ],
          given: [
            "* ",
            "Ef "
          ],
          name: "Icelandic",
          native: "\xCDslenska",
          rule: [
            "Rule"
          ],
          scenario: [
            "Atbur\xF0ar\xE1s"
          ],
          scenarioOutline: [
            "L\xFDsing Atbur\xF0ar\xE1sar",
            "L\xFDsing D\xE6ma"
          ],
          then: [
            "* ",
            "\xDE\xE1 "
          ],
          when: [
            "* ",
            "\xDEegar "
          ]
        },
        it: {
          and: [
            "* ",
            "E ",
            "Ed "
          ],
          background: [
            "Contesto"
          ],
          but: [
            "* ",
            "Ma "
          ],
          examples: [
            "Esempi"
          ],
          feature: [
            "Funzionalit\xE0",
            "Esigenza di Business",
            "Abilit\xE0"
          ],
          given: [
            "* ",
            "Dato ",
            "Data ",
            "Dati ",
            "Date "
          ],
          name: "Italian",
          native: "italiano",
          rule: [
            "Regola"
          ],
          scenario: [
            "Esempio",
            "Scenario"
          ],
          scenarioOutline: [
            "Schema dello scenario"
          ],
          then: [
            "* ",
            "Allora "
          ],
          when: [
            "* ",
            "Quando "
          ]
        },
        ja: {
          and: [
            "* ",
            "\u4E14\u3064",
            "\u304B\u3064"
          ],
          background: [
            "\u80CC\u666F"
          ],
          but: [
            "* ",
            "\u7136\u3057",
            "\u3057\u304B\u3057",
            "\u4F46\u3057",
            "\u305F\u3060\u3057"
          ],
          examples: [
            "\u4F8B",
            "\u30B5\u30F3\u30D7\u30EB"
          ],
          feature: [
            "\u30D5\u30A3\u30FC\u30C1\u30E3",
            "\u6A5F\u80FD"
          ],
          given: [
            "* ",
            "\u524D\u63D0"
          ],
          name: "Japanese",
          native: "\u65E5\u672C\u8A9E",
          rule: [
            "\u30EB\u30FC\u30EB"
          ],
          scenario: [
            "\u30B7\u30CA\u30EA\u30AA"
          ],
          scenarioOutline: [
            "\u30B7\u30CA\u30EA\u30AA\u30A2\u30A6\u30C8\u30E9\u30A4\u30F3",
            "\u30B7\u30CA\u30EA\u30AA\u30C6\u30F3\u30D7\u30EC\u30FC\u30C8",
            "\u30C6\u30F3\u30D7\u30EC",
            "\u30B7\u30CA\u30EA\u30AA\u30C6\u30F3\u30D7\u30EC"
          ],
          then: [
            "* ",
            "\u306A\u3089\u3070"
          ],
          when: [
            "* ",
            "\u3082\u3057"
          ]
        },
        jv: {
          and: [
            "* ",
            "Lan "
          ],
          background: [
            "Dasar"
          ],
          but: [
            "* ",
            "Tapi ",
            "Nanging ",
            "Ananging "
          ],
          examples: [
            "Conto",
            "Contone"
          ],
          feature: [
            "Fitur"
          ],
          given: [
            "* ",
            "Nalika ",
            "Nalikaning "
          ],
          name: "Javanese",
          native: "Basa Jawa",
          rule: [
            "Rule"
          ],
          scenario: [
            "Skenario"
          ],
          scenarioOutline: [
            "Konsep skenario"
          ],
          then: [
            "* ",
            "Njuk ",
            "Banjur "
          ],
          when: [
            "* ",
            "Manawa ",
            "Menawa "
          ]
        },
        ka: {
          and: [
            "* ",
            "\u10D3\u10D0 ",
            "\u10D0\u10E1\u10D4\u10D5\u10D4 "
          ],
          background: [
            "\u10D9\u10DD\u10DC\u10E2\u10D4\u10E5\u10E1\u10E2\u10D8"
          ],
          but: [
            "* ",
            "\u10DB\u10D0\u10D2\u10E0\u10D0\u10DB ",
            "\u10D7\u10E3\u10DB\u10EA\u10D0 "
          ],
          examples: [
            "\u10DB\u10D0\u10D2\u10D0\u10DA\u10D8\u10D7\u10D4\u10D1\u10D8"
          ],
          feature: [
            "\u10D7\u10D5\u10D8\u10E1\u10D4\u10D1\u10D0",
            "\u10DB\u10DD\u10D7\u10EE\u10DD\u10D5\u10DC\u10D0"
          ],
          given: [
            "* ",
            "\u10DB\u10DD\u10EA\u10D4\u10DB\u10E3\u10DA\u10D8 ",
            "\u10DB\u10DD\u10EA\u10D4\u10DB\u10E3\u10DA\u10D8\u10D0 ",
            "\u10D5\u10D7\u10E5\u10D5\u10D0\u10D7 "
          ],
          name: "Georgian",
          native: "\u10E5\u10D0\u10E0\u10D7\u10E3\u10DA\u10D8",
          rule: [
            "\u10EC\u10D4\u10E1\u10D8"
          ],
          scenario: [
            "\u10DB\u10D0\u10D2\u10D0\u10DA\u10D8\u10D7\u10D0\u10D3",
            "\u10DB\u10D0\u10D2\u10D0\u10DA\u10D8\u10D7\u10D8",
            "\u10DB\u10D0\u10D2",
            "\u10E1\u10EA\u10D4\u10DC\u10D0\u10E0\u10D8"
          ],
          scenarioOutline: [
            "\u10E1\u10EA\u10D4\u10DC\u10D0\u10E0\u10D8\u10E1 \u10DC\u10D8\u10DB\u10E3\u10E8\u10D8",
            "\u10E1\u10EA\u10D4\u10DC\u10D0\u10E0\u10D8\u10E1 \u10E8\u10D0\u10D1\u10DA\u10DD\u10DC\u10D8",
            "\u10DC\u10D8\u10DB\u10E3\u10E8\u10D8",
            "\u10E8\u10D0\u10D1\u10DA\u10DD\u10DC\u10D8"
          ],
          then: [
            "* ",
            "\u10DB\u10D0\u10E8\u10D8\u10DC "
          ],
          when: [
            "* ",
            "\u10E0\u10DD\u10D3\u10D4\u10E1\u10D0\u10EA ",
            "\u10E0\u10DD\u10EA\u10D0 ",
            "\u10E0\u10DD\u10D2\u10DD\u10E0\u10EA \u10D9\u10D8 ",
            "\u10D7\u10E3 "
          ]
        },
        kn: {
          and: [
            "* ",
            "\u0CAE\u0CA4\u0CCD\u0CA4\u0CC1 "
          ],
          background: [
            "\u0CB9\u0CBF\u0CA8\u0CCD\u0CA8\u0CC6\u0CB2\u0CC6"
          ],
          but: [
            "* ",
            "\u0C86\u0CA6\u0CB0\u0CC6 "
          ],
          examples: [
            "\u0C89\u0CA6\u0CBE\u0CB9\u0CB0\u0CA3\u0CC6\u0C97\u0CB3\u0CC1"
          ],
          feature: [
            "\u0CB9\u0CC6\u0C9A\u0CCD\u0C9A\u0CB3"
          ],
          given: [
            "* ",
            "\u0CA8\u0CBF\u0CD5\u0CA1\u0CBF\u0CA6 "
          ],
          name: "Kannada",
          native: "\u0C95\u0CA8\u0CCD\u0CA8\u0CA1",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0C89\u0CA6\u0CBE\u0CB9\u0CB0\u0CA3\u0CC6",
            "\u0C95\u0CA5\u0CBE\u0CB8\u0CBE\u0CB0\u0CBE\u0C82\u0CB6"
          ],
          scenarioOutline: [
            "\u0CB5\u0CBF\u0CB5\u0CB0\u0CA3\u0CC6"
          ],
          then: [
            "* ",
            "\u0CA8\u0C82\u0CA4\u0CB0 "
          ],
          when: [
            "* ",
            "\u0CB8\u0CCD\u0CA5\u0CBF\u0CA4\u0CBF\u0CAF\u0CA8\u0CCD\u0CA8\u0CC1 "
          ]
        },
        ko: {
          and: [
            "* ",
            "\uADF8\uB9AC\uACE0 "
          ],
          background: [
            "\uBC30\uACBD"
          ],
          but: [
            "* ",
            "\uD558\uC9C0\uB9CC ",
            "\uB2E8 "
          ],
          examples: [
            "\uC608"
          ],
          feature: [
            "\uAE30\uB2A5"
          ],
          given: [
            "* ",
            "\uC870\uAC74 ",
            "\uBA3C\uC800 "
          ],
          name: "Korean",
          native: "\uD55C\uAD6D\uC5B4",
          rule: [
            "Rule"
          ],
          scenario: [
            "\uC2DC\uB098\uB9AC\uC624"
          ],
          scenarioOutline: [
            "\uC2DC\uB098\uB9AC\uC624 \uAC1C\uC694"
          ],
          then: [
            "* ",
            "\uADF8\uB7EC\uBA74 "
          ],
          when: [
            "* ",
            "\uB9CC\uC77C ",
            "\uB9CC\uC57D "
          ]
        },
        lt: {
          and: [
            "* ",
            "Ir "
          ],
          background: [
            "Kontekstas"
          ],
          but: [
            "* ",
            "Bet "
          ],
          examples: [
            "Pavyzd\u017Eiai",
            "Scenarijai",
            "Variantai"
          ],
          feature: [
            "Savyb\u0117"
          ],
          given: [
            "* ",
            "Duota "
          ],
          name: "Lithuanian",
          native: "lietuvi\u0173 kalba",
          rule: [
            "Rule"
          ],
          scenario: [
            "Pavyzdys",
            "Scenarijus"
          ],
          scenarioOutline: [
            "Scenarijaus \u0161ablonas"
          ],
          then: [
            "* ",
            "Tada "
          ],
          when: [
            "* ",
            "Kai "
          ]
        },
        lu: {
          and: [
            "* ",
            "an ",
            "a "
          ],
          background: [
            "Hannergrond"
          ],
          but: [
            "* ",
            "awer ",
            "m\xE4 "
          ],
          examples: [
            "Beispiller"
          ],
          feature: [
            "Funktionalit\xE9it"
          ],
          given: [
            "* ",
            "ugeholl "
          ],
          name: "Luxemburgish",
          native: "L\xEBtzebuergesch",
          rule: [
            "Rule"
          ],
          scenario: [
            "Beispill",
            "Szenario"
          ],
          scenarioOutline: [
            "Plang vum Szenario"
          ],
          then: [
            "* ",
            "dann "
          ],
          when: [
            "* ",
            "wann "
          ]
        },
        lv: {
          and: [
            "* ",
            "Un "
          ],
          background: [
            "Konteksts",
            "Situ\u0101cija"
          ],
          but: [
            "* ",
            "Bet "
          ],
          examples: [
            "Piem\u0113ri",
            "Paraugs"
          ],
          feature: [
            "Funkcionalit\u0101te",
            "F\u012B\u010Da"
          ],
          given: [
            "* ",
            "Kad "
          ],
          name: "Latvian",
          native: "latvie\u0161u",
          rule: [
            "Rule"
          ],
          scenario: [
            "Piem\u0113rs",
            "Scen\u0101rijs"
          ],
          scenarioOutline: [
            "Scen\u0101rijs p\u0113c parauga"
          ],
          then: [
            "* ",
            "Tad "
          ],
          when: [
            "* ",
            "Ja "
          ]
        },
        "mk-Cyrl": {
          and: [
            "* ",
            "\u0418 "
          ],
          background: [
            "\u041A\u043E\u043D\u0442\u0435\u043A\u0441\u0442",
            "\u0421\u043E\u0434\u0440\u0436\u0438\u043D\u0430"
          ],
          but: [
            "* ",
            "\u041D\u043E "
          ],
          examples: [
            "\u041F\u0440\u0438\u043C\u0435\u0440\u0438",
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0430"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u043D\u043E\u0441\u0442",
            "\u0411\u0438\u0437\u043D\u0438\u0441 \u043F\u043E\u0442\u0440\u0435\u0431\u0430",
            "\u041C\u043E\u0436\u043D\u043E\u0441\u0442"
          ],
          given: [
            "* ",
            "\u0414\u0430\u0434\u0435\u043D\u043E ",
            "\u0414\u0430\u0434\u0435\u043D\u0430 "
          ],
          name: "Macedonian",
          native: "\u041C\u0430\u043A\u0435\u0434\u043E\u043D\u0441\u043A\u0438",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u041F\u0440\u0438\u043C\u0435\u0440",
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u043E",
            "\u041D\u0430 \u043F\u0440\u0438\u043C\u0435\u0440"
          ],
          scenarioOutline: [
            "\u041F\u0440\u0435\u0433\u043B\u0435\u0434 \u043D\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0430",
            "\u0421\u043A\u0438\u0446\u0430",
            "\u041A\u043E\u043D\u0446\u0435\u043F\u0442"
          ],
          then: [
            "* ",
            "\u0422\u043E\u0433\u0430\u0448 "
          ],
          when: [
            "* ",
            "\u041A\u043E\u0433\u0430 "
          ]
        },
        "mk-Latn": {
          and: [
            "* ",
            "I "
          ],
          background: [
            "Kontekst",
            "Sodrzhina"
          ],
          but: [
            "* ",
            "No "
          ],
          examples: [
            "Primeri",
            "Scenaria"
          ],
          feature: [
            "Funkcionalnost",
            "Biznis potreba",
            "Mozhnost"
          ],
          given: [
            "* ",
            "Dadeno ",
            "Dadena "
          ],
          name: "Macedonian (Latin)",
          native: "Makedonski (Latinica)",
          rule: [
            "Rule"
          ],
          scenario: [
            "Scenario",
            "Na primer"
          ],
          scenarioOutline: [
            "Pregled na scenarija",
            "Skica",
            "Koncept"
          ],
          then: [
            "* ",
            "Togash "
          ],
          when: [
            "* ",
            "Koga "
          ]
        },
        mn: {
          and: [
            "* ",
            "\u041C\u04E9\u043D ",
            "\u0422\u044D\u0433\u044D\u044D\u0434 "
          ],
          background: [
            "\u0410\u0433\u0443\u0443\u043B\u0433\u0430"
          ],
          but: [
            "* ",
            "\u0413\u044D\u0445\u0434\u044D\u044D ",
            "\u0425\u0430\u0440\u0438\u043D "
          ],
          examples: [
            "\u0422\u0443\u0445\u0430\u0439\u043B\u0431\u0430\u043B"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446",
            "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B"
          ],
          given: [
            "* ",
            "\u04E8\u0433\u04E9\u0433\u0434\u0441\u04E9\u043D \u043D\u044C ",
            "\u0410\u043D\u0445 "
          ],
          name: "Mongolian",
          native: "\u043C\u043E\u043D\u0433\u043E\u043B",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0421\u0446\u0435\u043D\u0430\u0440"
          ],
          scenarioOutline: [
            "\u0421\u0446\u0435\u043D\u0430\u0440\u044B\u043D \u0442\u04E9\u043B\u04E9\u0432\u043B\u04E9\u0433\u04E9\u04E9"
          ],
          then: [
            "* ",
            "\u0422\u044D\u0433\u044D\u0445\u044D\u0434 ",
            "\u04AE\u04AF\u043D\u0438\u0439 \u0434\u0430\u0440\u0430\u0430 "
          ],
          when: [
            "* ",
            "\u0425\u044D\u0440\u044D\u0432 "
          ]
        },
        ne: {
          and: [
            "* ",
            "\u0930 ",
            "\u0905\u0928\u093F "
          ],
          background: [
            "\u092A\u0943\u0937\u094D\u0920\u092D\u0942\u092E\u0940"
          ],
          but: [
            "* ",
            "\u0924\u0930 "
          ],
          examples: [
            "\u0909\u0926\u093E\u0939\u0930\u0923",
            "\u0909\u0926\u093E\u0939\u0930\u0923\u0939\u0930\u0941"
          ],
          feature: [
            "\u0938\u0941\u0935\u093F\u0927\u093E",
            "\u0935\u093F\u0936\u0947\u0937\u0924\u093E"
          ],
          given: [
            "* ",
            "\u0926\u093F\u0907\u090F\u0915\u094B ",
            "\u0926\u093F\u090F\u0915\u094B ",
            "\u092F\u0926\u093F "
          ],
          name: "Nepali",
          native: "\u0928\u0947\u092A\u093E\u0932\u0940",
          rule: [
            "\u0928\u093F\u092F\u092E"
          ],
          scenario: [
            "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F"
          ],
          scenarioOutline: [
            "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F \u0930\u0942\u092A\u0930\u0947\u0916\u093E"
          ],
          then: [
            "* ",
            "\u0924\u094D\u092F\u0938\u092A\u091B\u093F ",
            "\u0905\u0928\u0940 "
          ],
          when: [
            "* ",
            "\u091C\u092C "
          ]
        },
        nl: {
          and: [
            "* ",
            "En "
          ],
          background: [
            "Achtergrond"
          ],
          but: [
            "* ",
            "Maar "
          ],
          examples: [
            "Voorbeelden"
          ],
          feature: [
            "Functionaliteit"
          ],
          given: [
            "* ",
            "Gegeven ",
            "Stel "
          ],
          name: "Dutch",
          native: "Nederlands",
          rule: [
            "Regel"
          ],
          scenario: [
            "Voorbeeld",
            "Scenario"
          ],
          scenarioOutline: [
            "Abstract Scenario"
          ],
          then: [
            "* ",
            "Dan "
          ],
          when: [
            "* ",
            "Als ",
            "Wanneer "
          ]
        },
        no: {
          and: [
            "* ",
            "Og "
          ],
          background: [
            "Bakgrunn"
          ],
          but: [
            "* ",
            "Men "
          ],
          examples: [
            "Eksempler"
          ],
          feature: [
            "Egenskap"
          ],
          given: [
            "* ",
            "Gitt "
          ],
          name: "Norwegian",
          native: "norsk",
          rule: [
            "Regel"
          ],
          scenario: [
            "Eksempel",
            "Scenario"
          ],
          scenarioOutline: [
            "Scenariomal",
            "Abstrakt Scenario"
          ],
          then: [
            "* ",
            "S\xE5 "
          ],
          when: [
            "* ",
            "N\xE5r "
          ]
        },
        pa: {
          and: [
            "* ",
            "\u0A05\u0A24\u0A47 "
          ],
          background: [
            "\u0A2A\u0A3F\u0A1B\u0A4B\u0A15\u0A5C"
          ],
          but: [
            "* ",
            "\u0A2A\u0A30 "
          ],
          examples: [
            "\u0A09\u0A26\u0A3E\u0A39\u0A30\u0A28\u0A3E\u0A02"
          ],
          feature: [
            "\u0A16\u0A3E\u0A38\u0A40\u0A05\u0A24",
            "\u0A2E\u0A41\u0A39\u0A3E\u0A02\u0A26\u0A30\u0A3E",
            "\u0A28\u0A15\u0A36 \u0A28\u0A41\u0A39\u0A3E\u0A30"
          ],
          given: [
            "* ",
            "\u0A1C\u0A47\u0A15\u0A30 ",
            "\u0A1C\u0A3F\u0A35\u0A47\u0A02 \u0A15\u0A3F "
          ],
          name: "Panjabi",
          native: "\u0A2A\u0A70\u0A1C\u0A3E\u0A2C\u0A40",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0A09\u0A26\u0A3E\u0A39\u0A30\u0A28",
            "\u0A2A\u0A1F\u0A15\u0A25\u0A3E"
          ],
          scenarioOutline: [
            "\u0A2A\u0A1F\u0A15\u0A25\u0A3E \u0A22\u0A3E\u0A02\u0A1A\u0A3E",
            "\u0A2A\u0A1F\u0A15\u0A25\u0A3E \u0A30\u0A42\u0A2A \u0A30\u0A47\u0A16\u0A3E"
          ],
          then: [
            "* ",
            "\u0A24\u0A26 "
          ],
          when: [
            "* ",
            "\u0A1C\u0A26\u0A4B\u0A02 "
          ]
        },
        pl: {
          and: [
            "* ",
            "Oraz ",
            "I "
          ],
          background: [
            "Za\u0142o\u017Cenia"
          ],
          but: [
            "* ",
            "Ale "
          ],
          examples: [
            "Przyk\u0142ady"
          ],
          feature: [
            "W\u0142a\u015Bciwo\u015B\u0107",
            "Funkcja",
            "Aspekt",
            "Potrzeba biznesowa"
          ],
          given: [
            "* ",
            "Zak\u0142adaj\u0105c ",
            "Maj\u0105c ",
            "Zak\u0142adaj\u0105c, \u017Ce "
          ],
          name: "Polish",
          native: "polski",
          rule: [
            "Zasada",
            "Regu\u0142a"
          ],
          scenario: [
            "Przyk\u0142ad",
            "Scenariusz"
          ],
          scenarioOutline: [
            "Szablon scenariusza"
          ],
          then: [
            "* ",
            "Wtedy "
          ],
          when: [
            "* ",
            "Je\u017Celi ",
            "Je\u015Bli ",
            "Gdy ",
            "Kiedy "
          ]
        },
        pt: {
          and: [
            "* ",
            "E "
          ],
          background: [
            "Contexto",
            "Cen\xE1rio de Fundo",
            "Cenario de Fundo",
            "Fundo"
          ],
          but: [
            "* ",
            "Mas "
          ],
          examples: [
            "Exemplos",
            "Cen\xE1rios",
            "Cenarios"
          ],
          feature: [
            "Funcionalidade",
            "Caracter\xEDstica",
            "Caracteristica"
          ],
          given: [
            "* ",
            "Dado ",
            "Dada ",
            "Dados ",
            "Dadas "
          ],
          name: "Portuguese",
          native: "portugu\xEAs",
          rule: [
            "Regra"
          ],
          scenario: [
            "Exemplo",
            "Cen\xE1rio",
            "Cenario"
          ],
          scenarioOutline: [
            "Esquema do Cen\xE1rio",
            "Esquema do Cenario",
            "Delinea\xE7\xE3o do Cen\xE1rio",
            "Delineacao do Cenario"
          ],
          then: [
            "* ",
            "Ent\xE3o ",
            "Entao "
          ],
          when: [
            "* ",
            "Quando "
          ]
        },
        ro: {
          and: [
            "* ",
            "Si ",
            "\u0218i ",
            "\u015Ei "
          ],
          background: [
            "Context"
          ],
          but: [
            "* ",
            "Dar "
          ],
          examples: [
            "Exemple"
          ],
          feature: [
            "Functionalitate",
            "Func\u021Bionalitate",
            "Func\u0163ionalitate"
          ],
          given: [
            "* ",
            "Date fiind ",
            "Dat fiind ",
            "Dat\u0103 fiind",
            "Dati fiind ",
            "Da\u021Bi fiind ",
            "Da\u0163i fiind "
          ],
          name: "Romanian",
          native: "rom\xE2n\u0103",
          rule: [
            "Rule"
          ],
          scenario: [
            "Exemplu",
            "Scenariu"
          ],
          scenarioOutline: [
            "Structura scenariu",
            "Structur\u0103 scenariu"
          ],
          then: [
            "* ",
            "Atunci "
          ],
          when: [
            "* ",
            "Cand ",
            "C\xE2nd "
          ]
        },
        ru: {
          and: [
            "* ",
            "\u0418 ",
            "\u041A \u0442\u043E\u043C\u0443 \u0436\u0435 ",
            "\u0422\u0430\u043A\u0436\u0435 "
          ],
          background: [
            "\u041F\u0440\u0435\u0434\u044B\u0441\u0442\u043E\u0440\u0438\u044F",
            "\u041A\u043E\u043D\u0442\u0435\u043A\u0441\u0442"
          ],
          but: [
            "* ",
            "\u041D\u043E ",
            "\u0410 ",
            "\u0418\u043D\u0430\u0447\u0435 "
          ],
          examples: [
            "\u041F\u0440\u0438\u043C\u0435\u0440\u044B"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446\u0438\u044F",
            "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u044C\u043D\u043E\u0441\u0442\u044C",
            "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B",
            "\u0421\u0432\u043E\u0439\u0441\u0442\u0432\u043E",
            "\u0424\u0438\u0447\u0430"
          ],
          given: [
            "* ",
            "\u0414\u043E\u043F\u0443\u0441\u0442\u0438\u043C ",
            "\u0414\u0430\u043D\u043E ",
            "\u041F\u0443\u0441\u0442\u044C "
          ],
          name: "Russian",
          native: "\u0440\u0443\u0441\u0441\u043A\u0438\u0439",
          rule: [
            "\u041F\u0440\u0430\u0432\u0438\u043B\u043E"
          ],
          scenario: [
            "\u041F\u0440\u0438\u043C\u0435\u0440",
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
          ],
          scenarioOutline: [
            "\u0421\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u044F",
            "\u0428\u0430\u0431\u043B\u043E\u043D \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u044F"
          ],
          then: [
            "* ",
            "\u0422\u043E ",
            "\u0417\u0430\u0442\u0435\u043C ",
            "\u0422\u043E\u0433\u0434\u0430 "
          ],
          when: [
            "* ",
            "\u041A\u043E\u0433\u0434\u0430 ",
            "\u0415\u0441\u043B\u0438 "
          ]
        },
        sk: {
          and: [
            "* ",
            "A ",
            "A tie\u017E ",
            "A taktie\u017E ",
            "A z\xE1rove\u0148 "
          ],
          background: [
            "Pozadie"
          ],
          but: [
            "* ",
            "Ale "
          ],
          examples: [
            "Pr\xEDklady"
          ],
          feature: [
            "Po\u017Eiadavka",
            "Funkcia",
            "Vlastnos\u0165"
          ],
          given: [
            "* ",
            "Pokia\u013E ",
            "Za predpokladu "
          ],
          name: "Slovak",
          native: "Slovensky",
          rule: [
            "Rule"
          ],
          scenario: [
            "Pr\xEDklad",
            "Scen\xE1r"
          ],
          scenarioOutline: [
            "N\xE1\u010Drt Scen\xE1ru",
            "N\xE1\u010Drt Scen\xE1ra",
            "Osnova Scen\xE1ra"
          ],
          then: [
            "* ",
            "Tak ",
            "Potom "
          ],
          when: [
            "* ",
            "Ke\u010F ",
            "Ak "
          ]
        },
        sl: {
          and: [
            "In ",
            "Ter "
          ],
          background: [
            "Kontekst",
            "Osnova",
            "Ozadje"
          ],
          but: [
            "Toda ",
            "Ampak ",
            "Vendar "
          ],
          examples: [
            "Primeri",
            "Scenariji"
          ],
          feature: [
            "Funkcionalnost",
            "Funkcija",
            "Mo\u017Enosti",
            "Moznosti",
            "Lastnost",
            "Zna\u010Dilnost"
          ],
          given: [
            "Dano ",
            "Podano ",
            "Zaradi ",
            "Privzeto "
          ],
          name: "Slovenian",
          native: "Slovenski",
          rule: [
            "Rule"
          ],
          scenario: [
            "Primer",
            "Scenarij"
          ],
          scenarioOutline: [
            "Struktura scenarija",
            "Skica",
            "Koncept",
            "Oris scenarija",
            "Osnutek"
          ],
          then: [
            "Nato ",
            "Potem ",
            "Takrat "
          ],
          when: [
            "Ko ",
            "Ce ",
            "\u010Ce ",
            "Kadar "
          ]
        },
        "sr-Cyrl": {
          and: [
            "* ",
            "\u0418 "
          ],
          background: [
            "\u041A\u043E\u043D\u0442\u0435\u043A\u0441\u0442",
            "\u041E\u0441\u043D\u043E\u0432\u0430",
            "\u041F\u043E\u0437\u0430\u0434\u0438\u043D\u0430"
          ],
          but: [
            "* ",
            "\u0410\u043B\u0438 "
          ],
          examples: [
            "\u041F\u0440\u0438\u043C\u0435\u0440\u0438",
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0438"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u043D\u043E\u0441\u0442",
            "\u041C\u043E\u0433\u0443\u045B\u043D\u043E\u0441\u0442",
            "\u041E\u0441\u043E\u0431\u0438\u043D\u0430"
          ],
          given: [
            "* ",
            "\u0417\u0430 \u0434\u0430\u0442\u043E ",
            "\u0417\u0430 \u0434\u0430\u0442\u0435 ",
            "\u0417\u0430 \u0434\u0430\u0442\u0438 "
          ],
          name: "Serbian",
          native: "\u0421\u0440\u043F\u0441\u043A\u0438",
          rule: [
            "\u041F\u0440\u0430\u0432\u0438\u043B\u043E"
          ],
          scenario: [
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u043E",
            "\u041F\u0440\u0438\u043C\u0435\u0440"
          ],
          scenarioOutline: [
            "\u0421\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0430",
            "\u0421\u043A\u0438\u0446\u0430",
            "\u041A\u043E\u043D\u0446\u0435\u043F\u0442"
          ],
          then: [
            "* ",
            "\u041E\u043D\u0434\u0430 "
          ],
          when: [
            "* ",
            "\u041A\u0430\u0434\u0430 ",
            "\u041A\u0430\u0434 "
          ]
        },
        "sr-Latn": {
          and: [
            "* ",
            "I "
          ],
          background: [
            "Kontekst",
            "Osnova",
            "Pozadina"
          ],
          but: [
            "* ",
            "Ali "
          ],
          examples: [
            "Primeri",
            "Scenariji"
          ],
          feature: [
            "Funkcionalnost",
            "Mogu\u0107nost",
            "Mogucnost",
            "Osobina"
          ],
          given: [
            "* ",
            "Za dato ",
            "Za date ",
            "Za dati "
          ],
          name: "Serbian (Latin)",
          native: "Srpski (Latinica)",
          rule: [
            "Pravilo"
          ],
          scenario: [
            "Scenario",
            "Primer"
          ],
          scenarioOutline: [
            "Struktura scenarija",
            "Skica",
            "Koncept"
          ],
          then: [
            "* ",
            "Onda "
          ],
          when: [
            "* ",
            "Kada ",
            "Kad "
          ]
        },
        sv: {
          and: [
            "* ",
            "Och "
          ],
          background: [
            "Bakgrund"
          ],
          but: [
            "* ",
            "Men "
          ],
          examples: [
            "Exempel"
          ],
          feature: [
            "Egenskap"
          ],
          given: [
            "* ",
            "Givet "
          ],
          name: "Swedish",
          native: "Svenska",
          rule: [
            "Regel"
          ],
          scenario: [
            "Scenario"
          ],
          scenarioOutline: [
            "Abstrakt Scenario",
            "Scenariomall"
          ],
          then: [
            "* ",
            "S\xE5 "
          ],
          when: [
            "* ",
            "N\xE4r "
          ]
        },
        ta: {
          and: [
            "* ",
            "\u0BAE\u0BC7\u0BB2\u0BC1\u0BAE\u0BCD ",
            "\u0BAE\u0BB1\u0BCD\u0BB1\u0BC1\u0BAE\u0BCD "
          ],
          background: [
            "\u0BAA\u0BBF\u0BA9\u0BCD\u0BA9\u0BA3\u0BBF"
          ],
          but: [
            "* ",
            "\u0B86\u0BA9\u0BBE\u0BB2\u0BCD "
          ],
          examples: [
            "\u0B8E\u0B9F\u0BC1\u0BA4\u0BCD\u0BA4\u0BC1\u0B95\u0BCD\u0B95\u0BBE\u0B9F\u0BCD\u0B9F\u0BC1\u0B95\u0BB3\u0BCD",
            "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF\u0B95\u0BB3\u0BCD",
            "\u0BA8\u0BBF\u0BB2\u0BC8\u0BAE\u0BC8\u0B95\u0BB3\u0BBF\u0BB2\u0BCD"
          ],
          feature: [
            "\u0B85\u0BAE\u0BCD\u0B9A\u0BAE\u0BCD",
            "\u0BB5\u0BA3\u0BBF\u0B95 \u0BA4\u0BC7\u0BB5\u0BC8",
            "\u0BA4\u0BBF\u0BB1\u0BA9\u0BCD"
          ],
          given: [
            "* ",
            "\u0B95\u0BC6\u0BBE\u0B9F\u0BC1\u0B95\u0BCD\u0B95\u0BAA\u0BCD\u0BAA\u0B9F\u0BCD\u0B9F "
          ],
          name: "Tamil",
          native: "\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0B89\u0BA4\u0BBE\u0BB0\u0BA3\u0BAE\u0BBE\u0B95",
            "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF"
          ],
          scenarioOutline: [
            "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF \u0B9A\u0BC1\u0BB0\u0BC1\u0B95\u0BCD\u0B95\u0BAE\u0BCD",
            "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF \u0BB5\u0BBE\u0BB0\u0BCD\u0BAA\u0BCD\u0BAA\u0BC1\u0BB0\u0BC1"
          ],
          then: [
            "* ",
            "\u0B85\u0BAA\u0BCD\u0BAA\u0BC6\u0BBE\u0BB4\u0BC1\u0BA4\u0BC1 "
          ],
          when: [
            "* ",
            "\u0B8E\u0BAA\u0BCD\u0BAA\u0BC7\u0BBE\u0BA4\u0BC1 "
          ]
        },
        th: {
          and: [
            "* ",
            "\u0E41\u0E25\u0E30 "
          ],
          background: [
            "\u0E41\u0E19\u0E27\u0E04\u0E34\u0E14"
          ],
          but: [
            "* ",
            "\u0E41\u0E15\u0E48 "
          ],
          examples: [
            "\u0E0A\u0E38\u0E14\u0E02\u0E2D\u0E07\u0E15\u0E31\u0E27\u0E2D\u0E22\u0E48\u0E32\u0E07",
            "\u0E0A\u0E38\u0E14\u0E02\u0E2D\u0E07\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C"
          ],
          feature: [
            "\u0E42\u0E04\u0E23\u0E07\u0E2B\u0E25\u0E31\u0E01",
            "\u0E04\u0E27\u0E32\u0E21\u0E15\u0E49\u0E2D\u0E07\u0E01\u0E32\u0E23\u0E17\u0E32\u0E07\u0E18\u0E38\u0E23\u0E01\u0E34\u0E08",
            "\u0E04\u0E27\u0E32\u0E21\u0E2A\u0E32\u0E21\u0E32\u0E23\u0E16"
          ],
          given: [
            "* ",
            "\u0E01\u0E33\u0E2B\u0E19\u0E14\u0E43\u0E2B\u0E49 "
          ],
          name: "Thai",
          native: "\u0E44\u0E17\u0E22",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C"
          ],
          scenarioOutline: [
            "\u0E2A\u0E23\u0E38\u0E1B\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C",
            "\u0E42\u0E04\u0E23\u0E07\u0E2A\u0E23\u0E49\u0E32\u0E07\u0E02\u0E2D\u0E07\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C"
          ],
          then: [
            "* ",
            "\u0E14\u0E31\u0E07\u0E19\u0E31\u0E49\u0E19 "
          ],
          when: [
            "* ",
            "\u0E40\u0E21\u0E37\u0E48\u0E2D "
          ]
        },
        te: {
          and: [
            "* ",
            "\u0C2E\u0C30\u0C3F\u0C2F\u0C41 "
          ],
          background: [
            "\u0C28\u0C47\u0C2A\u0C25\u0C4D\u0C2F\u0C02"
          ],
          but: [
            "* ",
            "\u0C15\u0C3E\u0C28\u0C3F "
          ],
          examples: [
            "\u0C09\u0C26\u0C3E\u0C39\u0C30\u0C23\u0C32\u0C41"
          ],
          feature: [
            "\u0C17\u0C41\u0C23\u0C2E\u0C41"
          ],
          given: [
            "* ",
            "\u0C1A\u0C46\u0C2A\u0C4D\u0C2A\u0C2C\u0C21\u0C3F\u0C28\u0C26\u0C3F "
          ],
          name: "Telugu",
          native: "\u0C24\u0C46\u0C32\u0C41\u0C17\u0C41",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0C09\u0C26\u0C3E\u0C39\u0C30\u0C23",
            "\u0C38\u0C28\u0C4D\u0C28\u0C3F\u0C35\u0C47\u0C36\u0C02"
          ],
          scenarioOutline: [
            "\u0C15\u0C25\u0C28\u0C02"
          ],
          then: [
            "* ",
            "\u0C05\u0C2A\u0C4D\u0C2A\u0C41\u0C21\u0C41 "
          ],
          when: [
            "* ",
            "\u0C08 \u0C2A\u0C30\u0C3F\u0C38\u0C4D\u0C25\u0C3F\u0C24\u0C3F\u0C32\u0C4B "
          ]
        },
        tlh: {
          and: [
            "* ",
            "'ej ",
            "latlh "
          ],
          background: [
            "mo'"
          ],
          but: [
            "* ",
            "'ach ",
            "'a "
          ],
          examples: [
            "ghantoH",
            "lutmey"
          ],
          feature: [
            "Qap",
            "Qu'meH 'ut",
            "perbogh",
            "poQbogh malja'",
            "laH"
          ],
          given: [
            "* ",
            "ghu' noblu' ",
            "DaH ghu' bejlu' "
          ],
          name: "Klingon",
          native: "tlhIngan",
          rule: [
            "Rule"
          ],
          scenario: [
            "lut"
          ],
          scenarioOutline: [
            "lut chovnatlh"
          ],
          then: [
            "* ",
            "vaj "
          ],
          when: [
            "* ",
            "qaSDI' "
          ]
        },
        tr: {
          and: [
            "* ",
            "Ve "
          ],
          background: [
            "Ge\xE7mi\u015F"
          ],
          but: [
            "* ",
            "Fakat ",
            "Ama "
          ],
          examples: [
            "\xD6rnekler"
          ],
          feature: [
            "\xD6zellik"
          ],
          given: [
            "* ",
            "Diyelim ki "
          ],
          name: "Turkish",
          native: "T\xFCrk\xE7e",
          rule: [
            "Kural"
          ],
          scenario: [
            "\xD6rnek",
            "Senaryo"
          ],
          scenarioOutline: [
            "Senaryo tasla\u011F\u0131"
          ],
          then: [
            "* ",
            "O zaman "
          ],
          when: [
            "* ",
            "E\u011Fer ki "
          ]
        },
        tt: {
          and: [
            "* ",
            "\u04BA\u04D9\u043C ",
            "\u0412\u04D9 "
          ],
          background: [
            "\u041A\u0435\u0440\u0435\u0448"
          ],
          but: [
            "* ",
            "\u041B\u04D9\u043A\u0438\u043D ",
            "\u04D8\u043C\u043C\u0430 "
          ],
          examples: [
            "\u04AE\u0440\u043D\u04D9\u043A\u043B\u04D9\u0440",
            "\u041C\u0438\u0441\u0430\u043B\u043B\u0430\u0440"
          ],
          feature: [
            "\u041C\u04E9\u043C\u043A\u0438\u043D\u043B\u0435\u043A",
            "\u04AE\u0437\u0435\u043D\u0447\u04D9\u043B\u0435\u043A\u043B\u0435\u043B\u0435\u043A"
          ],
          given: [
            "* ",
            "\u04D8\u0439\u0442\u0438\u043A "
          ],
          name: "Tatar",
          native: "\u0422\u0430\u0442\u0430\u0440\u0447\u0430",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
          ],
          scenarioOutline: [
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439\u043D\u044B\u04A3 \u0442\u04E9\u0437\u0435\u043B\u0435\u0448\u0435"
          ],
          then: [
            "* ",
            "\u041D\u04D9\u0442\u0438\u0497\u04D9\u0434\u04D9 "
          ],
          when: [
            "* ",
            "\u04D8\u0433\u04D9\u0440 "
          ]
        },
        uk: {
          and: [
            "* ",
            "\u0406 ",
            "\u0410 \u0442\u0430\u043A\u043E\u0436 ",
            "\u0422\u0430 "
          ],
          background: [
            "\u041F\u0435\u0440\u0435\u0434\u0443\u043C\u043E\u0432\u0430"
          ],
          but: [
            "* ",
            "\u0410\u043B\u0435 "
          ],
          examples: [
            "\u041F\u0440\u0438\u043A\u043B\u0430\u0434\u0438"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446\u0456\u043E\u043D\u0430\u043B"
          ],
          given: [
            "* ",
            "\u041F\u0440\u0438\u043F\u0443\u0441\u0442\u0438\u043C\u043E ",
            "\u041F\u0440\u0438\u043F\u0443\u0441\u0442\u0438\u043C\u043E, \u0449\u043E ",
            "\u041D\u0435\u0445\u0430\u0439 ",
            "\u0414\u0430\u043D\u043E "
          ],
          name: "Ukrainian",
          native: "\u0423\u043A\u0440\u0430\u0457\u043D\u0441\u044C\u043A\u0430",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u041F\u0440\u0438\u043A\u043B\u0430\u0434",
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0456\u0439"
          ],
          scenarioOutline: [
            "\u0421\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0456\u044E"
          ],
          then: [
            "* ",
            "\u0422\u043E ",
            "\u0422\u043E\u0434\u0456 "
          ],
          when: [
            "* ",
            "\u042F\u043A\u0449\u043E ",
            "\u041A\u043E\u043B\u0438 "
          ]
        },
        ur: {
          and: [
            "* ",
            "\u0627\u0648\u0631 "
          ],
          background: [
            "\u067E\u0633 \u0645\u0646\u0638\u0631"
          ],
          but: [
            "* ",
            "\u0644\u06CC\u06A9\u0646 "
          ],
          examples: [
            "\u0645\u062B\u0627\u0644\u06CC\u06BA"
          ],
          feature: [
            "\u0635\u0644\u0627\u062D\u06CC\u062A",
            "\u06A9\u0627\u0631\u0648\u0628\u0627\u0631 \u06A9\u06CC \u0636\u0631\u0648\u0631\u062A",
            "\u062E\u0635\u0648\u0635\u06CC\u062A"
          ],
          given: [
            "* ",
            "\u0627\u06AF\u0631 ",
            "\u0628\u0627\u0644\u0641\u0631\u0636 ",
            "\u0641\u0631\u0636 \u06A9\u06CC\u0627 "
          ],
          name: "Urdu",
          native: "\u0627\u0631\u062F\u0648",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0645\u0646\u0638\u0631\u0646\u0627\u0645\u06C1"
          ],
          scenarioOutline: [
            "\u0645\u0646\u0638\u0631 \u0646\u0627\u0645\u06D2 \u06A9\u0627 \u062E\u0627\u06A9\u06C1"
          ],
          then: [
            "* ",
            "\u067E\u06BE\u0631 ",
            "\u062A\u0628 "
          ],
          when: [
            "* ",
            "\u062C\u0628 "
          ]
        },
        uz: {
          and: [
            "* ",
            "\u0412\u0430 "
          ],
          background: [
            "\u0422\u0430\u0440\u0438\u0445"
          ],
          but: [
            "* ",
            "\u041B\u0435\u043A\u0438\u043D ",
            "\u0411\u0438\u0440\u043E\u043A ",
            "\u0410\u043C\u043C\u043E "
          ],
          examples: [
            "\u041C\u0438\u0441\u043E\u043B\u043B\u0430\u0440"
          ],
          feature: [
            "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B"
          ],
          given: [
            "* ",
            "Belgilangan "
          ],
          name: "Uzbek",
          native: "\u0423\u0437\u0431\u0435\u043A\u0447\u0430",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
          ],
          scenarioOutline: [
            "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439 \u0441\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430\u0441\u0438"
          ],
          then: [
            "* ",
            "\u0423\u043D\u0434\u0430 "
          ],
          when: [
            "* ",
            "\u0410\u0433\u0430\u0440 "
          ]
        },
        vi: {
          and: [
            "* ",
            "V\xE0 "
          ],
          background: [
            "B\u1ED1i c\u1EA3nh"
          ],
          but: [
            "* ",
            "Nh\u01B0ng "
          ],
          examples: [
            "D\u1EEF li\u1EC7u"
          ],
          feature: [
            "T\xEDnh n\u0103ng"
          ],
          given: [
            "* ",
            "Bi\u1EBFt ",
            "Cho "
          ],
          name: "Vietnamese",
          native: "Ti\u1EBFng Vi\u1EC7t",
          rule: [
            "Quy t\u1EAFc"
          ],
          scenario: [
            "T\xECnh hu\u1ED1ng",
            "K\u1ECBch b\u1EA3n"
          ],
          scenarioOutline: [
            "Khung t\xECnh hu\u1ED1ng",
            "Khung k\u1ECBch b\u1EA3n"
          ],
          then: [
            "* ",
            "Th\xEC "
          ],
          when: [
            "* ",
            "Khi "
          ]
        },
        "zh-CN": {
          and: [
            "* ",
            "\u800C\u4E14",
            "\u5E76\u4E14",
            "\u540C\u65F6"
          ],
          background: [
            "\u80CC\u666F"
          ],
          but: [
            "* ",
            "\u4F46\u662F"
          ],
          examples: [
            "\u4F8B\u5B50"
          ],
          feature: [
            "\u529F\u80FD"
          ],
          given: [
            "* ",
            "\u5047\u5982",
            "\u5047\u8BBE",
            "\u5047\u5B9A"
          ],
          name: "Chinese simplified",
          native: "\u7B80\u4F53\u4E2D\u6587",
          rule: [
            "Rule",
            "\u89C4\u5219"
          ],
          scenario: [
            "\u573A\u666F",
            "\u5267\u672C"
          ],
          scenarioOutline: [
            "\u573A\u666F\u5927\u7EB2",
            "\u5267\u672C\u5927\u7EB2"
          ],
          then: [
            "* ",
            "\u90A3\u4E48"
          ],
          when: [
            "* ",
            "\u5F53"
          ]
        },
        ml: {
          and: [
            "* ",
            "\u0D12\u0D2A\u0D4D\u0D2A\u0D02"
          ],
          background: [
            "\u0D2A\u0D36\u0D4D\u0D1A\u0D3E\u0D24\u0D4D\u0D24\u0D32\u0D02"
          ],
          but: [
            "* ",
            "\u0D2A\u0D15\u0D4D\u0D37\u0D47"
          ],
          examples: [
            "\u0D09\u0D26\u0D3E\u0D39\u0D30\u0D23\u0D19\u0D4D\u0D19\u0D7E"
          ],
          feature: [
            "\u0D38\u0D35\u0D3F\u0D36\u0D47\u0D37\u0D24"
          ],
          given: [
            "* ",
            "\u0D28\u0D7D\u0D15\u0D3F\u0D2F\u0D24\u0D4D"
          ],
          name: "Malayalam",
          native: "\u0D2E\u0D32\u0D2F\u0D3E\u0D33\u0D02",
          rule: [
            "\u0D28\u0D3F\u0D2F\u0D2E\u0D02"
          ],
          scenario: [
            "\u0D30\u0D02\u0D17\u0D02"
          ],
          scenarioOutline: [
            "\u0D38\u0D3E\u0D39\u0D1A\u0D30\u0D4D\u0D2F\u0D24\u0D4D\u0D24\u0D3F\u0D28\u0D4D\u0D31\u0D46 \u0D30\u0D42\u0D2A\u0D30\u0D47\u0D16"
          ],
          then: [
            "* ",
            "\u0D2A\u0D3F\u0D28\u0D4D\u0D28\u0D46"
          ],
          when: [
            "\u0D0E\u0D2A\u0D4D\u0D2A\u0D47\u0D3E\u0D7E"
          ]
        },
        "zh-TW": {
          and: [
            "* ",
            "\u800C\u4E14",
            "\u4E26\u4E14",
            "\u540C\u6642"
          ],
          background: [
            "\u80CC\u666F"
          ],
          but: [
            "* ",
            "\u4F46\u662F"
          ],
          examples: [
            "\u4F8B\u5B50"
          ],
          feature: [
            "\u529F\u80FD"
          ],
          given: [
            "* ",
            "\u5047\u5982",
            "\u5047\u8A2D",
            "\u5047\u5B9A"
          ],
          name: "Chinese traditional",
          native: "\u7E41\u9AD4\u4E2D\u6587",
          rule: [
            "Rule"
          ],
          scenario: [
            "\u5834\u666F",
            "\u5287\u672C"
          ],
          scenarioOutline: [
            "\u5834\u666F\u5927\u7DB1",
            "\u5287\u672C\u5927\u7DB1"
          ],
          then: [
            "* ",
            "\u90A3\u9EBC"
          ],
          when: [
            "* ",
            "\u7576"
          ]
        },
        mr: {
          and: [
            "* ",
            "\u0906\u0923\u093F ",
            "\u0924\u0938\u0947\u091A "
          ],
          background: [
            "\u092A\u093E\u0930\u094D\u0936\u094D\u0935\u092D\u0942\u092E\u0940"
          ],
          but: [
            "* ",
            "\u092A\u0923 ",
            "\u092A\u0930\u0902\u0924\u0941 "
          ],
          examples: [
            "\u0909\u0926\u093E\u0939\u0930\u0923"
          ],
          feature: [
            "\u0935\u0948\u0936\u093F\u0937\u094D\u091F\u094D\u092F",
            "\u0938\u0941\u0935\u093F\u0927\u093E"
          ],
          given: [
            "* ",
            "\u091C\u0930",
            "\u0926\u093F\u0932\u0947\u0932\u094D\u092F\u093E \u092A\u094D\u0930\u092E\u093E\u0923\u0947 "
          ],
          name: "Marathi",
          native: "\u092E\u0930\u093E\u0920\u0940",
          rule: [
            "\u0928\u093F\u092F\u092E"
          ],
          scenario: [
            "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F"
          ],
          scenarioOutline: [
            "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F \u0930\u0942\u092A\u0930\u0947\u0916\u093E"
          ],
          then: [
            "* ",
            "\u092E\u0917 ",
            "\u0924\u0947\u0935\u094D\u0939\u093E "
          ],
          when: [
            "* ",
            "\u091C\u0947\u0935\u094D\u0939\u093E "
          ]
        },
        amh: {
          and: [
            "* ",
            "\u12A5\u1293 "
          ],
          background: [
            "\u1245\u12F5\u1218 \u1201\u1294\u1273",
            "\u1218\u1290\u123B",
            "\u1218\u1290\u123B \u1200\u1233\u1265"
          ],
          but: [
            "* ",
            "\u130D\u1295 "
          ],
          examples: [
            "\u121D\u1233\u120C\u12CE\u127D",
            "\u1201\u1293\u1274\u12CE\u127D"
          ],
          feature: [
            "\u1235\u122B",
            "\u12E8\u1270\u1348\u1208\u1308\u12CD \u1235\u122B",
            "\u12E8\u121A\u1348\u1208\u1308\u12CD \u12F5\u122D\u130A\u1275"
          ],
          given: [
            "* ",
            "\u12E8\u1270\u1230\u1320 "
          ],
          name: "Amharic",
          native: "\u12A0\u121B\u122D\u129B",
          rule: [
            "\u1205\u130D"
          ],
          scenario: [
            "\u121D\u1233\u120C",
            "\u1201\u1293\u1274"
          ],
          scenarioOutline: [
            "\u1201\u1293\u1274 \u12DD\u122D\u12DD\u122D",
            "\u1201\u1293\u1274 \u12A0\u1265\u1290\u1275"
          ],
          then: [
            "* ",
            "\u12A8\u12DA\u12EB "
          ],
          when: [
            "* ",
            "\u1218\u127C "
          ]
        }
      };
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/TimeConversion.js
  var require_TimeConversion = __commonJS({
    "node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/TimeConversion.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.millisecondsSinceEpochToTimestamp = millisecondsSinceEpochToTimestamp;
      exports.millisecondsToDuration = millisecondsToDuration2;
      exports.timestampToMillisecondsSinceEpoch = timestampToMillisecondsSinceEpoch;
      exports.durationToMilliseconds = durationToMilliseconds;
      exports.addDurations = addDurations;
      var MILLISECONDS_PER_SECOND = 1e3;
      var NANOSECONDS_PER_MILLISECOND = 1e6;
      var NANOSECONDS_PER_SECOND = 1e9;
      function millisecondsSinceEpochToTimestamp(millisecondsSinceEpoch) {
        return toSecondsAndNanos(millisecondsSinceEpoch);
      }
      function millisecondsToDuration2(durationInMilliseconds) {
        return toSecondsAndNanos(durationInMilliseconds);
      }
      function timestampToMillisecondsSinceEpoch(timestamp) {
        var seconds = timestamp.seconds, nanos = timestamp.nanos;
        return toMillis(seconds, nanos);
      }
      function durationToMilliseconds(duration) {
        var seconds = duration.seconds, nanos = duration.nanos;
        return toMillis(seconds, nanos);
      }
      function addDurations(durationA, durationB) {
        var seconds = +durationA.seconds + +durationB.seconds;
        var nanos = durationA.nanos + durationB.nanos;
        if (nanos >= NANOSECONDS_PER_SECOND) {
          seconds += 1;
          nanos -= NANOSECONDS_PER_SECOND;
        }
        return { seconds, nanos };
      }
      function toSecondsAndNanos(milliseconds) {
        var seconds = Math.floor(milliseconds / MILLISECONDS_PER_SECOND);
        var nanos = Math.floor(milliseconds % MILLISECONDS_PER_SECOND * NANOSECONDS_PER_MILLISECOND);
        return { seconds, nanos };
      }
      function toMillis(seconds, nanos) {
        var secondMillis = +seconds * MILLISECONDS_PER_SECOND;
        var nanoMillis = nanos / NANOSECONDS_PER_MILLISECOND;
        return secondMillis + nanoMillis;
      }
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/max.js
  var max_default;
  var init_max = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/max.js"() {
      max_default = "ffffffff-ffff-ffff-ffff-ffffffffffff";
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/nil.js
  var nil_default;
  var init_nil = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/nil.js"() {
      nil_default = "00000000-0000-0000-0000-000000000000";
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/regex.js
  var regex_default;
  var init_regex = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/regex.js"() {
      regex_default = /^(?:[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|00000000-0000-0000-0000-000000000000|ffffffff-ffff-ffff-ffff-ffffffffffff)$/i;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/validate.js
  function validate(uuid2) {
    return typeof uuid2 === "string" && regex_default.test(uuid2);
  }
  var validate_default;
  var init_validate = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/validate.js"() {
      init_regex();
      validate_default = validate;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/parse.js
  function parse(uuid2) {
    if (!validate_default(uuid2)) {
      throw TypeError("Invalid UUID");
    }
    let v;
    const arr = new Uint8Array(16);
    arr[0] = (v = parseInt(uuid2.slice(0, 8), 16)) >>> 24;
    arr[1] = v >>> 16 & 255;
    arr[2] = v >>> 8 & 255;
    arr[3] = v & 255;
    arr[4] = (v = parseInt(uuid2.slice(9, 13), 16)) >>> 8;
    arr[5] = v & 255;
    arr[6] = (v = parseInt(uuid2.slice(14, 18), 16)) >>> 8;
    arr[7] = v & 255;
    arr[8] = (v = parseInt(uuid2.slice(19, 23), 16)) >>> 8;
    arr[9] = v & 255;
    arr[10] = (v = parseInt(uuid2.slice(24, 36), 16)) / 1099511627776 & 255;
    arr[11] = v / 4294967296 & 255;
    arr[12] = v >>> 24 & 255;
    arr[13] = v >>> 16 & 255;
    arr[14] = v >>> 8 & 255;
    arr[15] = v & 255;
    return arr;
  }
  var parse_default;
  var init_parse = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/parse.js"() {
      init_validate();
      parse_default = parse;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/stringify.js
  function unsafeStringify(arr, offset = 0) {
    return (byteToHex[arr[offset + 0]] + byteToHex[arr[offset + 1]] + byteToHex[arr[offset + 2]] + byteToHex[arr[offset + 3]] + "-" + byteToHex[arr[offset + 4]] + byteToHex[arr[offset + 5]] + "-" + byteToHex[arr[offset + 6]] + byteToHex[arr[offset + 7]] + "-" + byteToHex[arr[offset + 8]] + byteToHex[arr[offset + 9]] + "-" + byteToHex[arr[offset + 10]] + byteToHex[arr[offset + 11]] + byteToHex[arr[offset + 12]] + byteToHex[arr[offset + 13]] + byteToHex[arr[offset + 14]] + byteToHex[arr[offset + 15]]).toLowerCase();
  }
  function stringify(arr, offset = 0) {
    const uuid2 = unsafeStringify(arr, offset);
    if (!validate_default(uuid2)) {
      throw TypeError("Stringified UUID is invalid");
    }
    return uuid2;
  }
  var byteToHex, stringify_default;
  var init_stringify = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/stringify.js"() {
      init_validate();
      byteToHex = [];
      for (let i = 0; i < 256; ++i) {
        byteToHex.push((i + 256).toString(16).slice(1));
      }
      stringify_default = stringify;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/rng.js
  function rng() {
    if (poolPtr > rnds8Pool.length - 16) {
      import_node_crypto.default.randomFillSync(rnds8Pool);
      poolPtr = 0;
    }
    return rnds8Pool.slice(poolPtr, poolPtr += 16);
  }
  var import_node_crypto, rnds8Pool, poolPtr;
  var init_rng = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/rng.js"() {
      import_node_crypto = __toESM(__require("node:crypto"));
      rnds8Pool = new Uint8Array(256);
      poolPtr = rnds8Pool.length;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v1.js
  function v1(options, buf, offset) {
    let i = buf && offset || 0;
    const b = buf || new Array(16);
    options = options || {};
    let node = options.node;
    let clockseq = options.clockseq;
    if (!options._v6) {
      if (!node) {
        node = _nodeId;
      }
      if (clockseq == null) {
        clockseq = _clockseq;
      }
    }
    if (node == null || clockseq == null) {
      const seedBytes = options.random || (options.rng || rng)();
      if (node == null) {
        node = [seedBytes[0], seedBytes[1], seedBytes[2], seedBytes[3], seedBytes[4], seedBytes[5]];
        if (!_nodeId && !options._v6) {
          node[0] |= 1;
          _nodeId = node;
        }
      }
      if (clockseq == null) {
        clockseq = (seedBytes[6] << 8 | seedBytes[7]) & 16383;
        if (_clockseq === void 0 && !options._v6) {
          _clockseq = clockseq;
        }
      }
    }
    let msecs = options.msecs !== void 0 ? options.msecs : Date.now();
    let nsecs = options.nsecs !== void 0 ? options.nsecs : _lastNSecs + 1;
    const dt = msecs - _lastMSecs + (nsecs - _lastNSecs) / 1e4;
    if (dt < 0 && options.clockseq === void 0) {
      clockseq = clockseq + 1 & 16383;
    }
    if ((dt < 0 || msecs > _lastMSecs) && options.nsecs === void 0) {
      nsecs = 0;
    }
    if (nsecs >= 1e4) {
      throw new Error("uuid.v1(): Can't create more than 10M uuids/sec");
    }
    _lastMSecs = msecs;
    _lastNSecs = nsecs;
    _clockseq = clockseq;
    msecs += 122192928e5;
    const tl = ((msecs & 268435455) * 1e4 + nsecs) % 4294967296;
    b[i++] = tl >>> 24 & 255;
    b[i++] = tl >>> 16 & 255;
    b[i++] = tl >>> 8 & 255;
    b[i++] = tl & 255;
    const tmh = msecs / 4294967296 * 1e4 & 268435455;
    b[i++] = tmh >>> 8 & 255;
    b[i++] = tmh & 255;
    b[i++] = tmh >>> 24 & 15 | 16;
    b[i++] = tmh >>> 16 & 255;
    b[i++] = clockseq >>> 8 | 128;
    b[i++] = clockseq & 255;
    for (let n = 0; n < 6; ++n) {
      b[i + n] = node[n];
    }
    return buf || unsafeStringify(b);
  }
  var _nodeId, _clockseq, _lastMSecs, _lastNSecs, v1_default;
  var init_v1 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v1.js"() {
      init_rng();
      init_stringify();
      _lastMSecs = 0;
      _lastNSecs = 0;
      v1_default = v1;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v1ToV6.js
  function v1ToV6(uuid2) {
    const v1Bytes = typeof uuid2 === "string" ? parse_default(uuid2) : uuid2;
    const v6Bytes = _v1ToV6(v1Bytes);
    return typeof uuid2 === "string" ? unsafeStringify(v6Bytes) : v6Bytes;
  }
  function _v1ToV6(v1Bytes, randomize = false) {
    return Uint8Array.of((v1Bytes[6] & 15) << 4 | v1Bytes[7] >> 4 & 15, (v1Bytes[7] & 15) << 4 | (v1Bytes[4] & 240) >> 4, (v1Bytes[4] & 15) << 4 | (v1Bytes[5] & 240) >> 4, (v1Bytes[5] & 15) << 4 | (v1Bytes[0] & 240) >> 4, (v1Bytes[0] & 15) << 4 | (v1Bytes[1] & 240) >> 4, (v1Bytes[1] & 15) << 4 | (v1Bytes[2] & 240) >> 4, 96 | v1Bytes[2] & 15, v1Bytes[3], v1Bytes[8], v1Bytes[9], v1Bytes[10], v1Bytes[11], v1Bytes[12], v1Bytes[13], v1Bytes[14], v1Bytes[15]);
  }
  var init_v1ToV6 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v1ToV6.js"() {
      init_parse();
      init_stringify();
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v35.js
  function stringToBytes(str) {
    str = unescape(encodeURIComponent(str));
    const bytes = [];
    for (let i = 0; i < str.length; ++i) {
      bytes.push(str.charCodeAt(i));
    }
    return bytes;
  }
  function v35(name, version3, hashfunc) {
    function generateUUID(value, namespace, buf, offset) {
      var _namespace;
      if (typeof value === "string") {
        value = stringToBytes(value);
      }
      if (typeof namespace === "string") {
        namespace = parse_default(namespace);
      }
      if (((_namespace = namespace) === null || _namespace === void 0 ? void 0 : _namespace.length) !== 16) {
        throw TypeError("Namespace must be array-like (16 iterable integer values, 0-255)");
      }
      let bytes = new Uint8Array(16 + value.length);
      bytes.set(namespace);
      bytes.set(value, namespace.length);
      bytes = hashfunc(bytes);
      bytes[6] = bytes[6] & 15 | version3;
      bytes[8] = bytes[8] & 63 | 128;
      if (buf) {
        offset = offset || 0;
        for (let i = 0; i < 16; ++i) {
          buf[offset + i] = bytes[i];
        }
        return buf;
      }
      return unsafeStringify(bytes);
    }
    try {
      generateUUID.name = name;
    } catch (err) {
    }
    generateUUID.DNS = DNS;
    generateUUID.URL = URL;
    return generateUUID;
  }
  var DNS, URL;
  var init_v35 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v35.js"() {
      init_stringify();
      init_parse();
      DNS = "6ba7b810-9dad-11d1-80b4-00c04fd430c8";
      URL = "6ba7b811-9dad-11d1-80b4-00c04fd430c8";
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/md5.js
  function md5(bytes) {
    if (Array.isArray(bytes)) {
      bytes = Buffer.from(bytes);
    } else if (typeof bytes === "string") {
      bytes = Buffer.from(bytes, "utf8");
    }
    return import_node_crypto2.default.createHash("md5").update(bytes).digest();
  }
  var import_node_crypto2, md5_default;
  var init_md5 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/md5.js"() {
      import_node_crypto2 = __toESM(__require("node:crypto"));
      md5_default = md5;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v3.js
  var v3, v3_default;
  var init_v3 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v3.js"() {
      init_v35();
      init_md5();
      v3 = v35("v3", 48, md5_default);
      v3_default = v3;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/native.js
  var import_node_crypto3, native_default;
  var init_native = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/native.js"() {
      import_node_crypto3 = __toESM(__require("node:crypto"));
      native_default = {
        randomUUID: import_node_crypto3.default.randomUUID
      };
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v4.js
  function v4(options, buf, offset) {
    if (native_default.randomUUID && !buf && !options) {
      return native_default.randomUUID();
    }
    options = options || {};
    const rnds = options.random || (options.rng || rng)();
    rnds[6] = rnds[6] & 15 | 64;
    rnds[8] = rnds[8] & 63 | 128;
    if (buf) {
      offset = offset || 0;
      for (let i = 0; i < 16; ++i) {
        buf[offset + i] = rnds[i];
      }
      return buf;
    }
    return unsafeStringify(rnds);
  }
  var v4_default;
  var init_v4 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v4.js"() {
      init_native();
      init_rng();
      init_stringify();
      v4_default = v4;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/sha1.js
  function sha1(bytes) {
    if (Array.isArray(bytes)) {
      bytes = Buffer.from(bytes);
    } else if (typeof bytes === "string") {
      bytes = Buffer.from(bytes, "utf8");
    }
    return import_node_crypto4.default.createHash("sha1").update(bytes).digest();
  }
  var import_node_crypto4, sha1_default;
  var init_sha1 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/sha1.js"() {
      import_node_crypto4 = __toESM(__require("node:crypto"));
      sha1_default = sha1;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v5.js
  var v5, v5_default;
  var init_v5 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v5.js"() {
      init_v35();
      init_sha1();
      v5 = v35("v5", 80, sha1_default);
      v5_default = v5;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v6.js
  function v6(options = {}, buf, offset = 0) {
    let bytes = v1_default({
      ...options,
      _v6: true
    }, new Uint8Array(16));
    bytes = v1ToV6(bytes);
    if (buf) {
      for (let i = 0; i < 16; i++) {
        buf[offset + i] = bytes[i];
      }
      return buf;
    }
    return unsafeStringify(bytes);
  }
  var init_v6 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v6.js"() {
      init_stringify();
      init_v1();
      init_v1ToV6();
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v6ToV1.js
  function v6ToV1(uuid2) {
    const v6Bytes = typeof uuid2 === "string" ? parse_default(uuid2) : uuid2;
    const v1Bytes = _v6ToV1(v6Bytes);
    return typeof uuid2 === "string" ? unsafeStringify(v1Bytes) : v1Bytes;
  }
  function _v6ToV1(v6Bytes) {
    return Uint8Array.of((v6Bytes[3] & 15) << 4 | v6Bytes[4] >> 4 & 15, (v6Bytes[4] & 15) << 4 | (v6Bytes[5] & 240) >> 4, (v6Bytes[5] & 15) << 4 | v6Bytes[6] & 15, v6Bytes[7], (v6Bytes[1] & 15) << 4 | (v6Bytes[2] & 240) >> 4, (v6Bytes[2] & 15) << 4 | (v6Bytes[3] & 240) >> 4, 16 | (v6Bytes[0] & 240) >> 4, (v6Bytes[0] & 15) << 4 | (v6Bytes[1] & 240) >> 4, v6Bytes[8], v6Bytes[9], v6Bytes[10], v6Bytes[11], v6Bytes[12], v6Bytes[13], v6Bytes[14], v6Bytes[15]);
  }
  var init_v6ToV1 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v6ToV1.js"() {
      init_parse();
      init_stringify();
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v7.js
  function v7(options, buf, offset) {
    options = options || {};
    let i = buf && offset || 0;
    const b = buf || new Uint8Array(16);
    const rnds = options.random || (options.rng || rng)();
    const msecs = options.msecs !== void 0 ? options.msecs : Date.now();
    let seq = options.seq !== void 0 ? options.seq : null;
    let seqHigh = _seqHigh;
    let seqLow = _seqLow;
    if (msecs > _msecs && options.msecs === void 0) {
      _msecs = msecs;
      if (seq !== null) {
        seqHigh = null;
        seqLow = null;
      }
    }
    if (seq !== null) {
      if (seq > 2147483647) {
        seq = 2147483647;
      }
      seqHigh = seq >>> 19 & 4095;
      seqLow = seq & 524287;
    }
    if (seqHigh === null || seqLow === null) {
      seqHigh = rnds[6] & 127;
      seqHigh = seqHigh << 8 | rnds[7];
      seqLow = rnds[8] & 63;
      seqLow = seqLow << 8 | rnds[9];
      seqLow = seqLow << 5 | rnds[10] >>> 3;
    }
    if (msecs + 1e4 > _msecs && seq === null) {
      if (++seqLow > 524287) {
        seqLow = 0;
        if (++seqHigh > 4095) {
          seqHigh = 0;
          _msecs++;
        }
      }
    } else {
      _msecs = msecs;
    }
    _seqHigh = seqHigh;
    _seqLow = seqLow;
    b[i++] = _msecs / 1099511627776 & 255;
    b[i++] = _msecs / 4294967296 & 255;
    b[i++] = _msecs / 16777216 & 255;
    b[i++] = _msecs / 65536 & 255;
    b[i++] = _msecs / 256 & 255;
    b[i++] = _msecs & 255;
    b[i++] = seqHigh >>> 4 & 15 | 112;
    b[i++] = seqHigh & 255;
    b[i++] = seqLow >>> 13 & 63 | 128;
    b[i++] = seqLow >>> 5 & 255;
    b[i++] = seqLow << 3 & 255 | rnds[10] & 7;
    b[i++] = rnds[11];
    b[i++] = rnds[12];
    b[i++] = rnds[13];
    b[i++] = rnds[14];
    b[i++] = rnds[15];
    return buf || unsafeStringify(b);
  }
  var _seqLow, _seqHigh, _msecs, v7_default;
  var init_v7 = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/v7.js"() {
      init_rng();
      init_stringify();
      _seqLow = null;
      _seqHigh = null;
      _msecs = 0;
      v7_default = v7;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/version.js
  function version(uuid2) {
    if (!validate_default(uuid2)) {
      throw TypeError("Invalid UUID");
    }
    return parseInt(uuid2.slice(14, 15), 16);
  }
  var version_default;
  var init_version = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/version.js"() {
      init_validate();
      version_default = version;
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/index.js
  var esm_node_exports = {};
  __export(esm_node_exports, {
    MAX: () => max_default,
    NIL: () => nil_default,
    parse: () => parse_default,
    stringify: () => stringify_default,
    v1: () => v1_default,
    v1ToV6: () => v1ToV6,
    v3: () => v3_default,
    v4: () => v4_default,
    v5: () => v5_default,
    v6: () => v6,
    v6ToV1: () => v6ToV1,
    v7: () => v7_default,
    validate: () => validate_default,
    version: () => version_default
  });
  var init_esm_node = __esm({
    "node_modules/@cucumber/gherkin/node_modules/uuid/dist/esm-node/index.js"() {
      init_max();
      init_nil();
      init_parse();
      init_stringify();
      init_v1();
      init_v1ToV6();
      init_v3();
      init_v4();
      init_v5();
      init_v6();
      init_v6ToV1();
      init_v7();
      init_validate();
      init_version();
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/IdGenerator.js
  var require_IdGenerator = __commonJS({
    "node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/IdGenerator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.uuid = uuid2;
      exports.incrementing = incrementing2;
      var uuid_1 = (init_esm_node(), __toCommonJS(esm_node_exports));
      function uuid2() {
        return function() {
          return (0, uuid_1.v4)();
        };
      }
      function incrementing2() {
        var next = 0;
        return function() {
          return (next++).toString();
        };
      }
    }
  });

  // node_modules/class-transformer/cjs/enums/transformation-type.enum.js
  var require_transformation_type_enum = __commonJS({
    "node_modules/class-transformer/cjs/enums/transformation-type.enum.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.TransformationType = void 0;
      var TransformationType;
      (function(TransformationType2) {
        TransformationType2[TransformationType2["PLAIN_TO_CLASS"] = 0] = "PLAIN_TO_CLASS";
        TransformationType2[TransformationType2["CLASS_TO_PLAIN"] = 1] = "CLASS_TO_PLAIN";
        TransformationType2[TransformationType2["CLASS_TO_CLASS"] = 2] = "CLASS_TO_CLASS";
      })(TransformationType = exports.TransformationType || (exports.TransformationType = {}));
    }
  });

  // node_modules/class-transformer/cjs/enums/index.js
  var require_enums = __commonJS({
    "node_modules/class-transformer/cjs/enums/index.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        Object.defineProperty(o, k2, { enumerable: true, get: function() {
          return m[k];
        } });
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __exportStar = exports && exports.__exportStar || function(m, exports2) {
        for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports2, p)) __createBinding(exports2, m, p);
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      __exportStar(require_transformation_type_enum(), exports);
    }
  });

  // node_modules/class-transformer/cjs/MetadataStorage.js
  var require_MetadataStorage = __commonJS({
    "node_modules/class-transformer/cjs/MetadataStorage.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.MetadataStorage = void 0;
      var enums_1 = require_enums();
      var MetadataStorage = class {
        constructor() {
          this._typeMetadatas = /* @__PURE__ */ new Map();
          this._transformMetadatas = /* @__PURE__ */ new Map();
          this._exposeMetadatas = /* @__PURE__ */ new Map();
          this._excludeMetadatas = /* @__PURE__ */ new Map();
          this._ancestorsMap = /* @__PURE__ */ new Map();
        }
        // -------------------------------------------------------------------------
        // Adder Methods
        // -------------------------------------------------------------------------
        addTypeMetadata(metadata) {
          if (!this._typeMetadatas.has(metadata.target)) {
            this._typeMetadatas.set(metadata.target, /* @__PURE__ */ new Map());
          }
          this._typeMetadatas.get(metadata.target).set(metadata.propertyName, metadata);
        }
        addTransformMetadata(metadata) {
          if (!this._transformMetadatas.has(metadata.target)) {
            this._transformMetadatas.set(metadata.target, /* @__PURE__ */ new Map());
          }
          if (!this._transformMetadatas.get(metadata.target).has(metadata.propertyName)) {
            this._transformMetadatas.get(metadata.target).set(metadata.propertyName, []);
          }
          this._transformMetadatas.get(metadata.target).get(metadata.propertyName).push(metadata);
        }
        addExposeMetadata(metadata) {
          if (!this._exposeMetadatas.has(metadata.target)) {
            this._exposeMetadatas.set(metadata.target, /* @__PURE__ */ new Map());
          }
          this._exposeMetadatas.get(metadata.target).set(metadata.propertyName, metadata);
        }
        addExcludeMetadata(metadata) {
          if (!this._excludeMetadatas.has(metadata.target)) {
            this._excludeMetadatas.set(metadata.target, /* @__PURE__ */ new Map());
          }
          this._excludeMetadatas.get(metadata.target).set(metadata.propertyName, metadata);
        }
        // -------------------------------------------------------------------------
        // Public Methods
        // -------------------------------------------------------------------------
        findTransformMetadatas(target, propertyName, transformationType) {
          return this.findMetadatas(this._transformMetadatas, target, propertyName).filter((metadata) => {
            if (!metadata.options)
              return true;
            if (metadata.options.toClassOnly === true && metadata.options.toPlainOnly === true)
              return true;
            if (metadata.options.toClassOnly === true) {
              return transformationType === enums_1.TransformationType.CLASS_TO_CLASS || transformationType === enums_1.TransformationType.PLAIN_TO_CLASS;
            }
            if (metadata.options.toPlainOnly === true) {
              return transformationType === enums_1.TransformationType.CLASS_TO_PLAIN;
            }
            return true;
          });
        }
        findExcludeMetadata(target, propertyName) {
          return this.findMetadata(this._excludeMetadatas, target, propertyName);
        }
        findExposeMetadata(target, propertyName) {
          return this.findMetadata(this._exposeMetadatas, target, propertyName);
        }
        findExposeMetadataByCustomName(target, name) {
          return this.getExposedMetadatas(target).find((metadata) => {
            return metadata.options && metadata.options.name === name;
          });
        }
        findTypeMetadata(target, propertyName) {
          return this.findMetadata(this._typeMetadatas, target, propertyName);
        }
        getStrategy(target) {
          const excludeMap = this._excludeMetadatas.get(target);
          const exclude = excludeMap && excludeMap.get(void 0);
          const exposeMap = this._exposeMetadatas.get(target);
          const expose = exposeMap && exposeMap.get(void 0);
          if (exclude && expose || !exclude && !expose)
            return "none";
          return exclude ? "excludeAll" : "exposeAll";
        }
        getExposedMetadatas(target) {
          return this.getMetadata(this._exposeMetadatas, target);
        }
        getExcludedMetadatas(target) {
          return this.getMetadata(this._excludeMetadatas, target);
        }
        getExposedProperties(target, transformationType) {
          return this.getExposedMetadatas(target).filter((metadata) => {
            if (!metadata.options)
              return true;
            if (metadata.options.toClassOnly === true && metadata.options.toPlainOnly === true)
              return true;
            if (metadata.options.toClassOnly === true) {
              return transformationType === enums_1.TransformationType.CLASS_TO_CLASS || transformationType === enums_1.TransformationType.PLAIN_TO_CLASS;
            }
            if (metadata.options.toPlainOnly === true) {
              return transformationType === enums_1.TransformationType.CLASS_TO_PLAIN;
            }
            return true;
          }).map((metadata) => metadata.propertyName);
        }
        getExcludedProperties(target, transformationType) {
          return this.getExcludedMetadatas(target).filter((metadata) => {
            if (!metadata.options)
              return true;
            if (metadata.options.toClassOnly === true && metadata.options.toPlainOnly === true)
              return true;
            if (metadata.options.toClassOnly === true) {
              return transformationType === enums_1.TransformationType.CLASS_TO_CLASS || transformationType === enums_1.TransformationType.PLAIN_TO_CLASS;
            }
            if (metadata.options.toPlainOnly === true) {
              return transformationType === enums_1.TransformationType.CLASS_TO_PLAIN;
            }
            return true;
          }).map((metadata) => metadata.propertyName);
        }
        clear() {
          this._typeMetadatas.clear();
          this._exposeMetadatas.clear();
          this._excludeMetadatas.clear();
          this._ancestorsMap.clear();
        }
        // -------------------------------------------------------------------------
        // Private Methods
        // -------------------------------------------------------------------------
        getMetadata(metadatas, target) {
          const metadataFromTargetMap = metadatas.get(target);
          let metadataFromTarget;
          if (metadataFromTargetMap) {
            metadataFromTarget = Array.from(metadataFromTargetMap.values()).filter((meta) => meta.propertyName !== void 0);
          }
          const metadataFromAncestors = [];
          for (const ancestor of this.getAncestors(target)) {
            const ancestorMetadataMap = metadatas.get(ancestor);
            if (ancestorMetadataMap) {
              const metadataFromAncestor = Array.from(ancestorMetadataMap.values()).filter((meta) => meta.propertyName !== void 0);
              metadataFromAncestors.push(...metadataFromAncestor);
            }
          }
          return metadataFromAncestors.concat(metadataFromTarget || []);
        }
        findMetadata(metadatas, target, propertyName) {
          const metadataFromTargetMap = metadatas.get(target);
          if (metadataFromTargetMap) {
            const metadataFromTarget = metadataFromTargetMap.get(propertyName);
            if (metadataFromTarget) {
              return metadataFromTarget;
            }
          }
          for (const ancestor of this.getAncestors(target)) {
            const ancestorMetadataMap = metadatas.get(ancestor);
            if (ancestorMetadataMap) {
              const ancestorResult = ancestorMetadataMap.get(propertyName);
              if (ancestorResult) {
                return ancestorResult;
              }
            }
          }
          return void 0;
        }
        findMetadatas(metadatas, target, propertyName) {
          const metadataFromTargetMap = metadatas.get(target);
          let metadataFromTarget;
          if (metadataFromTargetMap) {
            metadataFromTarget = metadataFromTargetMap.get(propertyName);
          }
          const metadataFromAncestorsTarget = [];
          for (const ancestor of this.getAncestors(target)) {
            const ancestorMetadataMap = metadatas.get(ancestor);
            if (ancestorMetadataMap) {
              if (ancestorMetadataMap.has(propertyName)) {
                metadataFromAncestorsTarget.push(...ancestorMetadataMap.get(propertyName));
              }
            }
          }
          return metadataFromAncestorsTarget.slice().reverse().concat((metadataFromTarget || []).slice().reverse());
        }
        getAncestors(target) {
          if (!target)
            return [];
          if (!this._ancestorsMap.has(target)) {
            const ancestors = [];
            for (let baseClass = Object.getPrototypeOf(target.prototype.constructor); typeof baseClass.prototype !== "undefined"; baseClass = Object.getPrototypeOf(baseClass.prototype.constructor)) {
              ancestors.push(baseClass);
            }
            this._ancestorsMap.set(target, ancestors);
          }
          return this._ancestorsMap.get(target);
        }
      };
      exports.MetadataStorage = MetadataStorage;
    }
  });

  // node_modules/class-transformer/cjs/storage.js
  var require_storage = __commonJS({
    "node_modules/class-transformer/cjs/storage.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.defaultMetadataStorage = void 0;
      var MetadataStorage_1 = require_MetadataStorage();
      exports.defaultMetadataStorage = new MetadataStorage_1.MetadataStorage();
    }
  });

  // node_modules/class-transformer/cjs/utils/get-global.util.js
  var require_get_global_util = __commonJS({
    "node_modules/class-transformer/cjs/utils/get-global.util.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.getGlobal = void 0;
      function getGlobal() {
        if (typeof globalThis !== "undefined") {
          return globalThis;
        }
        if (typeof global !== "undefined") {
          return global;
        }
        if (typeof window !== "undefined") {
          return window;
        }
        if (typeof self !== "undefined") {
          return self;
        }
      }
      exports.getGlobal = getGlobal;
    }
  });

  // node_modules/class-transformer/cjs/utils/is-promise.util.js
  var require_is_promise_util = __commonJS({
    "node_modules/class-transformer/cjs/utils/is-promise.util.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.isPromise = void 0;
      function isPromise(p) {
        return p !== null && typeof p === "object" && typeof p.then === "function";
      }
      exports.isPromise = isPromise;
    }
  });

  // node_modules/class-transformer/cjs/utils/index.js
  var require_utils = __commonJS({
    "node_modules/class-transformer/cjs/utils/index.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        Object.defineProperty(o, k2, { enumerable: true, get: function() {
          return m[k];
        } });
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __exportStar = exports && exports.__exportStar || function(m, exports2) {
        for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports2, p)) __createBinding(exports2, m, p);
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      __exportStar(require_get_global_util(), exports);
      __exportStar(require_is_promise_util(), exports);
    }
  });

  // node_modules/class-transformer/cjs/TransformOperationExecutor.js
  var require_TransformOperationExecutor = __commonJS({
    "node_modules/class-transformer/cjs/TransformOperationExecutor.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.TransformOperationExecutor = void 0;
      var storage_1 = require_storage();
      var enums_1 = require_enums();
      var utils_1 = require_utils();
      function instantiateArrayType(arrayType) {
        const array = new arrayType();
        if (!(array instanceof Set) && !("push" in array)) {
          return [];
        }
        return array;
      }
      var TransformOperationExecutor = class {
        // -------------------------------------------------------------------------
        // Constructor
        // -------------------------------------------------------------------------
        constructor(transformationType, options) {
          this.transformationType = transformationType;
          this.options = options;
          this.recursionStack = /* @__PURE__ */ new Set();
        }
        // -------------------------------------------------------------------------
        // Public Methods
        // -------------------------------------------------------------------------
        transform(source, value, targetType, arrayType, isMap, level = 0) {
          if (Array.isArray(value) || value instanceof Set) {
            const newValue = arrayType && this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS ? instantiateArrayType(arrayType) : [];
            value.forEach((subValue, index) => {
              const subSource = source ? source[index] : void 0;
              if (!this.options.enableCircularCheck || !this.isCircular(subValue)) {
                let realTargetType;
                if (typeof targetType !== "function" && targetType && targetType.options && targetType.options.discriminator && targetType.options.discriminator.property && targetType.options.discriminator.subTypes) {
                  if (this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS) {
                    realTargetType = targetType.options.discriminator.subTypes.find((subType) => subType.name === subValue[targetType.options.discriminator.property]);
                    const options = { newObject: newValue, object: subValue, property: void 0 };
                    const newType = targetType.typeFunction(options);
                    realTargetType === void 0 ? realTargetType = newType : realTargetType = realTargetType.value;
                    if (!targetType.options.keepDiscriminatorProperty)
                      delete subValue[targetType.options.discriminator.property];
                  }
                  if (this.transformationType === enums_1.TransformationType.CLASS_TO_CLASS) {
                    realTargetType = subValue.constructor;
                  }
                  if (this.transformationType === enums_1.TransformationType.CLASS_TO_PLAIN) {
                    subValue[targetType.options.discriminator.property] = targetType.options.discriminator.subTypes.find((subType) => subType.value === subValue.constructor).name;
                  }
                } else {
                  realTargetType = targetType;
                }
                const value2 = this.transform(subSource, subValue, realTargetType, void 0, subValue instanceof Map, level + 1);
                if (newValue instanceof Set) {
                  newValue.add(value2);
                } else {
                  newValue.push(value2);
                }
              } else if (this.transformationType === enums_1.TransformationType.CLASS_TO_CLASS) {
                if (newValue instanceof Set) {
                  newValue.add(subValue);
                } else {
                  newValue.push(subValue);
                }
              }
            });
            return newValue;
          } else if (targetType === String && !isMap) {
            if (value === null || value === void 0)
              return value;
            return String(value);
          } else if (targetType === Number && !isMap) {
            if (value === null || value === void 0)
              return value;
            return Number(value);
          } else if (targetType === Boolean && !isMap) {
            if (value === null || value === void 0)
              return value;
            return Boolean(value);
          } else if ((targetType === Date || value instanceof Date) && !isMap) {
            if (value instanceof Date) {
              return new Date(value.valueOf());
            }
            if (value === null || value === void 0)
              return value;
            return new Date(value);
          } else if (!!(0, utils_1.getGlobal)().Buffer && (targetType === Buffer || value instanceof Buffer) && !isMap) {
            if (value === null || value === void 0)
              return value;
            return Buffer.from(value);
          } else if ((0, utils_1.isPromise)(value) && !isMap) {
            return new Promise((resolve, reject) => {
              value.then((data) => resolve(this.transform(void 0, data, targetType, void 0, void 0, level + 1)), reject);
            });
          } else if (!isMap && value !== null && typeof value === "object" && typeof value.then === "function") {
            return value;
          } else if (typeof value === "object" && value !== null) {
            if (!targetType && value.constructor !== Object)
              if (!Array.isArray(value) && value.constructor === Array) {
              } else {
                targetType = value.constructor;
              }
            if (!targetType && source)
              targetType = source.constructor;
            if (this.options.enableCircularCheck) {
              this.recursionStack.add(value);
            }
            const keys = this.getKeys(targetType, value, isMap);
            let newValue = source ? source : {};
            if (!source && (this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS || this.transformationType === enums_1.TransformationType.CLASS_TO_CLASS)) {
              if (isMap) {
                newValue = /* @__PURE__ */ new Map();
              } else if (targetType) {
                newValue = new targetType();
              } else {
                newValue = {};
              }
            }
            for (const key of keys) {
              if (key === "__proto__" || key === "constructor") {
                continue;
              }
              const valueKey = key;
              let newValueKey = key, propertyName = key;
              if (!this.options.ignoreDecorators && targetType) {
                if (this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS) {
                  const exposeMetadata = storage_1.defaultMetadataStorage.findExposeMetadataByCustomName(targetType, key);
                  if (exposeMetadata) {
                    propertyName = exposeMetadata.propertyName;
                    newValueKey = exposeMetadata.propertyName;
                  }
                } else if (this.transformationType === enums_1.TransformationType.CLASS_TO_PLAIN || this.transformationType === enums_1.TransformationType.CLASS_TO_CLASS) {
                  const exposeMetadata = storage_1.defaultMetadataStorage.findExposeMetadata(targetType, key);
                  if (exposeMetadata && exposeMetadata.options && exposeMetadata.options.name) {
                    newValueKey = exposeMetadata.options.name;
                  }
                }
              }
              let subValue = void 0;
              if (this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS) {
                subValue = value[valueKey];
              } else {
                if (value instanceof Map) {
                  subValue = value.get(valueKey);
                } else if (value[valueKey] instanceof Function) {
                  subValue = value[valueKey]();
                } else {
                  subValue = value[valueKey];
                }
              }
              let type = void 0, isSubValueMap = subValue instanceof Map;
              if (targetType && isMap) {
                type = targetType;
              } else if (targetType) {
                const metadata = storage_1.defaultMetadataStorage.findTypeMetadata(targetType, propertyName);
                if (metadata) {
                  const options = { newObject: newValue, object: value, property: propertyName };
                  const newType = metadata.typeFunction ? metadata.typeFunction(options) : metadata.reflectedType;
                  if (metadata.options && metadata.options.discriminator && metadata.options.discriminator.property && metadata.options.discriminator.subTypes) {
                    if (!(value[valueKey] instanceof Array)) {
                      if (this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS) {
                        type = metadata.options.discriminator.subTypes.find((subType) => {
                          if (subValue && subValue instanceof Object && metadata.options.discriminator.property in subValue) {
                            return subType.name === subValue[metadata.options.discriminator.property];
                          }
                        });
                        type === void 0 ? type = newType : type = type.value;
                        if (!metadata.options.keepDiscriminatorProperty) {
                          if (subValue && subValue instanceof Object && metadata.options.discriminator.property in subValue) {
                            delete subValue[metadata.options.discriminator.property];
                          }
                        }
                      }
                      if (this.transformationType === enums_1.TransformationType.CLASS_TO_CLASS) {
                        type = subValue.constructor;
                      }
                      if (this.transformationType === enums_1.TransformationType.CLASS_TO_PLAIN) {
                        if (subValue) {
                          subValue[metadata.options.discriminator.property] = metadata.options.discriminator.subTypes.find((subType) => subType.value === subValue.constructor).name;
                        }
                      }
                    } else {
                      type = metadata;
                    }
                  } else {
                    type = newType;
                  }
                  isSubValueMap = isSubValueMap || metadata.reflectedType === Map;
                } else if (this.options.targetMaps) {
                  this.options.targetMaps.filter((map) => map.target === targetType && !!map.properties[propertyName]).forEach((map) => type = map.properties[propertyName]);
                } else if (this.options.enableImplicitConversion && this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS) {
                  const reflectedType = Reflect.getMetadata("design:type", targetType.prototype, propertyName);
                  if (reflectedType) {
                    type = reflectedType;
                  }
                }
              }
              const arrayType2 = Array.isArray(value[valueKey]) ? this.getReflectedType(targetType, propertyName) : void 0;
              const subSource = source ? source[valueKey] : void 0;
              if (newValue.constructor.prototype) {
                const descriptor = Object.getOwnPropertyDescriptor(newValue.constructor.prototype, newValueKey);
                if ((this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS || this.transformationType === enums_1.TransformationType.CLASS_TO_CLASS) && // eslint-disable-next-line @typescript-eslint/unbound-method
                (descriptor && !descriptor.set || newValue[newValueKey] instanceof Function))
                  continue;
              }
              if (!this.options.enableCircularCheck || !this.isCircular(subValue)) {
                const transformKey = this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS ? newValueKey : key;
                let finalValue;
                if (this.transformationType === enums_1.TransformationType.CLASS_TO_PLAIN) {
                  finalValue = value[transformKey];
                  finalValue = this.applyCustomTransformations(finalValue, targetType, transformKey, value, this.transformationType);
                  finalValue = value[transformKey] === finalValue ? subValue : finalValue;
                  finalValue = this.transform(subSource, finalValue, type, arrayType2, isSubValueMap, level + 1);
                } else {
                  if (subValue === void 0 && this.options.exposeDefaultValues) {
                    finalValue = newValue[newValueKey];
                  } else {
                    finalValue = this.transform(subSource, subValue, type, arrayType2, isSubValueMap, level + 1);
                    finalValue = this.applyCustomTransformations(finalValue, targetType, transformKey, value, this.transformationType);
                  }
                }
                if (finalValue !== void 0 || this.options.exposeUnsetFields) {
                  if (newValue instanceof Map) {
                    newValue.set(newValueKey, finalValue);
                  } else {
                    newValue[newValueKey] = finalValue;
                  }
                }
              } else if (this.transformationType === enums_1.TransformationType.CLASS_TO_CLASS) {
                let finalValue = subValue;
                finalValue = this.applyCustomTransformations(finalValue, targetType, key, value, this.transformationType);
                if (finalValue !== void 0 || this.options.exposeUnsetFields) {
                  if (newValue instanceof Map) {
                    newValue.set(newValueKey, finalValue);
                  } else {
                    newValue[newValueKey] = finalValue;
                  }
                }
              }
            }
            if (this.options.enableCircularCheck) {
              this.recursionStack.delete(value);
            }
            return newValue;
          } else {
            return value;
          }
        }
        applyCustomTransformations(value, target, key, obj, transformationType) {
          let metadatas = storage_1.defaultMetadataStorage.findTransformMetadatas(target, key, this.transformationType);
          if (this.options.version !== void 0) {
            metadatas = metadatas.filter((metadata) => {
              if (!metadata.options)
                return true;
              return this.checkVersion(metadata.options.since, metadata.options.until);
            });
          }
          if (this.options.groups && this.options.groups.length) {
            metadatas = metadatas.filter((metadata) => {
              if (!metadata.options)
                return true;
              return this.checkGroups(metadata.options.groups);
            });
          } else {
            metadatas = metadatas.filter((metadata) => {
              return !metadata.options || !metadata.options.groups || !metadata.options.groups.length;
            });
          }
          metadatas.forEach((metadata) => {
            value = metadata.transformFn({ value, key, obj, type: transformationType, options: this.options });
          });
          return value;
        }
        // preventing circular references
        isCircular(object) {
          return this.recursionStack.has(object);
        }
        getReflectedType(target, propertyName) {
          if (!target)
            return void 0;
          const meta = storage_1.defaultMetadataStorage.findTypeMetadata(target, propertyName);
          return meta ? meta.reflectedType : void 0;
        }
        getKeys(target, object, isMap) {
          let strategy = storage_1.defaultMetadataStorage.getStrategy(target);
          if (strategy === "none")
            strategy = this.options.strategy || "exposeAll";
          let keys = [];
          if (strategy === "exposeAll" || isMap) {
            if (object instanceof Map) {
              keys = Array.from(object.keys());
            } else {
              keys = Object.keys(object);
            }
          }
          if (isMap) {
            return keys;
          }
          if (this.options.ignoreDecorators && this.options.excludeExtraneousValues && target) {
            const exposedProperties = storage_1.defaultMetadataStorage.getExposedProperties(target, this.transformationType);
            const excludedProperties = storage_1.defaultMetadataStorage.getExcludedProperties(target, this.transformationType);
            keys = [...exposedProperties, ...excludedProperties];
          }
          if (!this.options.ignoreDecorators && target) {
            let exposedProperties = storage_1.defaultMetadataStorage.getExposedProperties(target, this.transformationType);
            if (this.transformationType === enums_1.TransformationType.PLAIN_TO_CLASS) {
              exposedProperties = exposedProperties.map((key) => {
                const exposeMetadata = storage_1.defaultMetadataStorage.findExposeMetadata(target, key);
                if (exposeMetadata && exposeMetadata.options && exposeMetadata.options.name) {
                  return exposeMetadata.options.name;
                }
                return key;
              });
            }
            if (this.options.excludeExtraneousValues) {
              keys = exposedProperties;
            } else {
              keys = keys.concat(exposedProperties);
            }
            const excludedProperties = storage_1.defaultMetadataStorage.getExcludedProperties(target, this.transformationType);
            if (excludedProperties.length > 0) {
              keys = keys.filter((key) => {
                return !excludedProperties.includes(key);
              });
            }
            if (this.options.version !== void 0) {
              keys = keys.filter((key) => {
                const exposeMetadata = storage_1.defaultMetadataStorage.findExposeMetadata(target, key);
                if (!exposeMetadata || !exposeMetadata.options)
                  return true;
                return this.checkVersion(exposeMetadata.options.since, exposeMetadata.options.until);
              });
            }
            if (this.options.groups && this.options.groups.length) {
              keys = keys.filter((key) => {
                const exposeMetadata = storage_1.defaultMetadataStorage.findExposeMetadata(target, key);
                if (!exposeMetadata || !exposeMetadata.options)
                  return true;
                return this.checkGroups(exposeMetadata.options.groups);
              });
            } else {
              keys = keys.filter((key) => {
                const exposeMetadata = storage_1.defaultMetadataStorage.findExposeMetadata(target, key);
                return !exposeMetadata || !exposeMetadata.options || !exposeMetadata.options.groups || !exposeMetadata.options.groups.length;
              });
            }
          }
          if (this.options.excludePrefixes && this.options.excludePrefixes.length) {
            keys = keys.filter((key) => this.options.excludePrefixes.every((prefix) => {
              return key.substr(0, prefix.length) !== prefix;
            }));
          }
          keys = keys.filter((key, index, self2) => {
            return self2.indexOf(key) === index;
          });
          return keys;
        }
        checkVersion(since, until) {
          let decision = true;
          if (decision && since)
            decision = this.options.version >= since;
          if (decision && until)
            decision = this.options.version < until;
          return decision;
        }
        checkGroups(groups) {
          if (!groups)
            return true;
          return this.options.groups.some((optionGroup) => groups.includes(optionGroup));
        }
      };
      exports.TransformOperationExecutor = TransformOperationExecutor;
    }
  });

  // node_modules/class-transformer/cjs/constants/default-options.constant.js
  var require_default_options_constant = __commonJS({
    "node_modules/class-transformer/cjs/constants/default-options.constant.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.defaultOptions = void 0;
      exports.defaultOptions = {
        enableCircularCheck: false,
        enableImplicitConversion: false,
        excludeExtraneousValues: false,
        excludePrefixes: void 0,
        exposeDefaultValues: false,
        exposeUnsetFields: true,
        groups: void 0,
        ignoreDecorators: false,
        strategy: void 0,
        targetMaps: void 0,
        version: void 0
      };
    }
  });

  // node_modules/class-transformer/cjs/ClassTransformer.js
  var require_ClassTransformer = __commonJS({
    "node_modules/class-transformer/cjs/ClassTransformer.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.ClassTransformer = void 0;
      var TransformOperationExecutor_1 = require_TransformOperationExecutor();
      var enums_1 = require_enums();
      var default_options_constant_1 = require_default_options_constant();
      var ClassTransformer = class {
        instanceToPlain(object, options) {
          const executor = new TransformOperationExecutor_1.TransformOperationExecutor(enums_1.TransformationType.CLASS_TO_PLAIN, {
            ...default_options_constant_1.defaultOptions,
            ...options
          });
          return executor.transform(void 0, object, void 0, void 0, void 0, void 0);
        }
        classToPlainFromExist(object, plainObject, options) {
          const executor = new TransformOperationExecutor_1.TransformOperationExecutor(enums_1.TransformationType.CLASS_TO_PLAIN, {
            ...default_options_constant_1.defaultOptions,
            ...options
          });
          return executor.transform(plainObject, object, void 0, void 0, void 0, void 0);
        }
        plainToInstance(cls, plain, options) {
          const executor = new TransformOperationExecutor_1.TransformOperationExecutor(enums_1.TransformationType.PLAIN_TO_CLASS, {
            ...default_options_constant_1.defaultOptions,
            ...options
          });
          return executor.transform(void 0, plain, cls, void 0, void 0, void 0);
        }
        plainToClassFromExist(clsObject, plain, options) {
          const executor = new TransformOperationExecutor_1.TransformOperationExecutor(enums_1.TransformationType.PLAIN_TO_CLASS, {
            ...default_options_constant_1.defaultOptions,
            ...options
          });
          return executor.transform(clsObject, plain, void 0, void 0, void 0, void 0);
        }
        instanceToInstance(object, options) {
          const executor = new TransformOperationExecutor_1.TransformOperationExecutor(enums_1.TransformationType.CLASS_TO_CLASS, {
            ...default_options_constant_1.defaultOptions,
            ...options
          });
          return executor.transform(void 0, object, void 0, void 0, void 0, void 0);
        }
        classToClassFromExist(object, fromObject, options) {
          const executor = new TransformOperationExecutor_1.TransformOperationExecutor(enums_1.TransformationType.CLASS_TO_CLASS, {
            ...default_options_constant_1.defaultOptions,
            ...options
          });
          return executor.transform(fromObject, object, void 0, void 0, void 0, void 0);
        }
        serialize(object, options) {
          return JSON.stringify(this.instanceToPlain(object, options));
        }
        /**
         * Deserializes given JSON string to a object of the given class.
         */
        deserialize(cls, json, options) {
          const jsonObject = JSON.parse(json);
          return this.plainToInstance(cls, jsonObject, options);
        }
        /**
         * Deserializes given JSON string to an array of objects of the given class.
         */
        deserializeArray(cls, json, options) {
          const jsonObject = JSON.parse(json);
          return this.plainToInstance(cls, jsonObject, options);
        }
      };
      exports.ClassTransformer = ClassTransformer;
    }
  });

  // node_modules/class-transformer/cjs/decorators/exclude.decorator.js
  var require_exclude_decorator = __commonJS({
    "node_modules/class-transformer/cjs/decorators/exclude.decorator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.Exclude = void 0;
      var storage_1 = require_storage();
      function Exclude(options = {}) {
        return function(object, propertyName) {
          storage_1.defaultMetadataStorage.addExcludeMetadata({
            target: object instanceof Function ? object : object.constructor,
            propertyName,
            options
          });
        };
      }
      exports.Exclude = Exclude;
    }
  });

  // node_modules/class-transformer/cjs/decorators/expose.decorator.js
  var require_expose_decorator = __commonJS({
    "node_modules/class-transformer/cjs/decorators/expose.decorator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.Expose = void 0;
      var storage_1 = require_storage();
      function Expose(options = {}) {
        return function(object, propertyName) {
          storage_1.defaultMetadataStorage.addExposeMetadata({
            target: object instanceof Function ? object : object.constructor,
            propertyName,
            options
          });
        };
      }
      exports.Expose = Expose;
    }
  });

  // node_modules/class-transformer/cjs/decorators/transform-instance-to-instance.decorator.js
  var require_transform_instance_to_instance_decorator = __commonJS({
    "node_modules/class-transformer/cjs/decorators/transform-instance-to-instance.decorator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.TransformInstanceToInstance = void 0;
      var ClassTransformer_1 = require_ClassTransformer();
      function TransformInstanceToInstance(params) {
        return function(target, propertyKey, descriptor) {
          const classTransformer = new ClassTransformer_1.ClassTransformer();
          const originalMethod = descriptor.value;
          descriptor.value = function(...args) {
            const result = originalMethod.apply(this, args);
            const isPromise = !!result && (typeof result === "object" || typeof result === "function") && typeof result.then === "function";
            return isPromise ? result.then((data) => classTransformer.instanceToInstance(data, params)) : classTransformer.instanceToInstance(result, params);
          };
        };
      }
      exports.TransformInstanceToInstance = TransformInstanceToInstance;
    }
  });

  // node_modules/class-transformer/cjs/decorators/transform-instance-to-plain.decorator.js
  var require_transform_instance_to_plain_decorator = __commonJS({
    "node_modules/class-transformer/cjs/decorators/transform-instance-to-plain.decorator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.TransformInstanceToPlain = void 0;
      var ClassTransformer_1 = require_ClassTransformer();
      function TransformInstanceToPlain(params) {
        return function(target, propertyKey, descriptor) {
          const classTransformer = new ClassTransformer_1.ClassTransformer();
          const originalMethod = descriptor.value;
          descriptor.value = function(...args) {
            const result = originalMethod.apply(this, args);
            const isPromise = !!result && (typeof result === "object" || typeof result === "function") && typeof result.then === "function";
            return isPromise ? result.then((data) => classTransformer.instanceToPlain(data, params)) : classTransformer.instanceToPlain(result, params);
          };
        };
      }
      exports.TransformInstanceToPlain = TransformInstanceToPlain;
    }
  });

  // node_modules/class-transformer/cjs/decorators/transform-plain-to-instance.decorator.js
  var require_transform_plain_to_instance_decorator = __commonJS({
    "node_modules/class-transformer/cjs/decorators/transform-plain-to-instance.decorator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.TransformPlainToInstance = void 0;
      var ClassTransformer_1 = require_ClassTransformer();
      function TransformPlainToInstance(classType, params) {
        return function(target, propertyKey, descriptor) {
          const classTransformer = new ClassTransformer_1.ClassTransformer();
          const originalMethod = descriptor.value;
          descriptor.value = function(...args) {
            const result = originalMethod.apply(this, args);
            const isPromise = !!result && (typeof result === "object" || typeof result === "function") && typeof result.then === "function";
            return isPromise ? result.then((data) => classTransformer.plainToInstance(classType, data, params)) : classTransformer.plainToInstance(classType, result, params);
          };
        };
      }
      exports.TransformPlainToInstance = TransformPlainToInstance;
    }
  });

  // node_modules/class-transformer/cjs/decorators/transform.decorator.js
  var require_transform_decorator = __commonJS({
    "node_modules/class-transformer/cjs/decorators/transform.decorator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.Transform = void 0;
      var storage_1 = require_storage();
      function Transform(transformFn, options = {}) {
        return function(target, propertyName) {
          storage_1.defaultMetadataStorage.addTransformMetadata({
            target: target.constructor,
            propertyName,
            transformFn,
            options
          });
        };
      }
      exports.Transform = Transform;
    }
  });

  // node_modules/class-transformer/cjs/decorators/type.decorator.js
  var require_type_decorator = __commonJS({
    "node_modules/class-transformer/cjs/decorators/type.decorator.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.Type = void 0;
      var storage_1 = require_storage();
      function Type2(typeFunction, options = {}) {
        return function(target, propertyName) {
          const reflectedType = Reflect.getMetadata("design:type", target, propertyName);
          storage_1.defaultMetadataStorage.addTypeMetadata({
            target: target.constructor,
            propertyName,
            reflectedType,
            typeFunction,
            options
          });
        };
      }
      exports.Type = Type2;
    }
  });

  // node_modules/class-transformer/cjs/decorators/index.js
  var require_decorators = __commonJS({
    "node_modules/class-transformer/cjs/decorators/index.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        Object.defineProperty(o, k2, { enumerable: true, get: function() {
          return m[k];
        } });
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __exportStar = exports && exports.__exportStar || function(m, exports2) {
        for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports2, p)) __createBinding(exports2, m, p);
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      __exportStar(require_exclude_decorator(), exports);
      __exportStar(require_expose_decorator(), exports);
      __exportStar(require_transform_instance_to_instance_decorator(), exports);
      __exportStar(require_transform_instance_to_plain_decorator(), exports);
      __exportStar(require_transform_plain_to_instance_decorator(), exports);
      __exportStar(require_transform_decorator(), exports);
      __exportStar(require_type_decorator(), exports);
    }
  });

  // node_modules/class-transformer/cjs/interfaces/decorator-options/expose-options.interface.js
  var require_expose_options_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/decorator-options/expose-options.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/decorator-options/exclude-options.interface.js
  var require_exclude_options_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/decorator-options/exclude-options.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/decorator-options/transform-options.interface.js
  var require_transform_options_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/decorator-options/transform-options.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/decorator-options/type-discriminator-descriptor.interface.js
  var require_type_discriminator_descriptor_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/decorator-options/type-discriminator-descriptor.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/decorator-options/type-options.interface.js
  var require_type_options_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/decorator-options/type-options.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/metadata/exclude-metadata.interface.js
  var require_exclude_metadata_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/metadata/exclude-metadata.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/metadata/expose-metadata.interface.js
  var require_expose_metadata_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/metadata/expose-metadata.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/metadata/transform-metadata.interface.js
  var require_transform_metadata_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/metadata/transform-metadata.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/metadata/transform-fn-params.interface.js
  var require_transform_fn_params_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/metadata/transform-fn-params.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/metadata/type-metadata.interface.js
  var require_type_metadata_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/metadata/type-metadata.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/class-constructor.type.js
  var require_class_constructor_type = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/class-constructor.type.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/class-transformer-options.interface.js
  var require_class_transformer_options_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/class-transformer-options.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/target-map.interface.js
  var require_target_map_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/target-map.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/type-help-options.interface.js
  var require_type_help_options_interface = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/type-help-options.interface.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
    }
  });

  // node_modules/class-transformer/cjs/interfaces/index.js
  var require_interfaces = __commonJS({
    "node_modules/class-transformer/cjs/interfaces/index.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        Object.defineProperty(o, k2, { enumerable: true, get: function() {
          return m[k];
        } });
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __exportStar = exports && exports.__exportStar || function(m, exports2) {
        for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports2, p)) __createBinding(exports2, m, p);
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      __exportStar(require_expose_options_interface(), exports);
      __exportStar(require_exclude_options_interface(), exports);
      __exportStar(require_transform_options_interface(), exports);
      __exportStar(require_type_discriminator_descriptor_interface(), exports);
      __exportStar(require_type_options_interface(), exports);
      __exportStar(require_exclude_metadata_interface(), exports);
      __exportStar(require_expose_metadata_interface(), exports);
      __exportStar(require_transform_metadata_interface(), exports);
      __exportStar(require_transform_fn_params_interface(), exports);
      __exportStar(require_type_metadata_interface(), exports);
      __exportStar(require_class_constructor_type(), exports);
      __exportStar(require_class_transformer_options_interface(), exports);
      __exportStar(require_target_map_interface(), exports);
      __exportStar(require_type_help_options_interface(), exports);
    }
  });

  // node_modules/class-transformer/cjs/index.js
  var require_cjs = __commonJS({
    "node_modules/class-transformer/cjs/index.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        Object.defineProperty(o, k2, { enumerable: true, get: function() {
          return m[k];
        } });
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __exportStar = exports && exports.__exportStar || function(m, exports2) {
        for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports2, p)) __createBinding(exports2, m, p);
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.deserializeArray = exports.deserialize = exports.serialize = exports.classToClassFromExist = exports.instanceToInstance = exports.plainToClassFromExist = exports.plainToInstance = exports.plainToClass = exports.classToPlainFromExist = exports.instanceToPlain = exports.classToPlain = exports.ClassTransformer = void 0;
      var ClassTransformer_1 = require_ClassTransformer();
      var ClassTransformer_2 = require_ClassTransformer();
      Object.defineProperty(exports, "ClassTransformer", { enumerable: true, get: function() {
        return ClassTransformer_2.ClassTransformer;
      } });
      __exportStar(require_decorators(), exports);
      __exportStar(require_interfaces(), exports);
      __exportStar(require_enums(), exports);
      var classTransformer = new ClassTransformer_1.ClassTransformer();
      function classToPlain(object, options) {
        return classTransformer.instanceToPlain(object, options);
      }
      exports.classToPlain = classToPlain;
      function instanceToPlain(object, options) {
        return classTransformer.instanceToPlain(object, options);
      }
      exports.instanceToPlain = instanceToPlain;
      function classToPlainFromExist(object, plainObject, options) {
        return classTransformer.classToPlainFromExist(object, plainObject, options);
      }
      exports.classToPlainFromExist = classToPlainFromExist;
      function plainToClass(cls, plain, options) {
        return classTransformer.plainToInstance(cls, plain, options);
      }
      exports.plainToClass = plainToClass;
      function plainToInstance(cls, plain, options) {
        return classTransformer.plainToInstance(cls, plain, options);
      }
      exports.plainToInstance = plainToInstance;
      function plainToClassFromExist(clsObject, plain, options) {
        return classTransformer.plainToClassFromExist(clsObject, plain, options);
      }
      exports.plainToClassFromExist = plainToClassFromExist;
      function instanceToInstance(object, options) {
        return classTransformer.instanceToInstance(object, options);
      }
      exports.instanceToInstance = instanceToInstance;
      function classToClassFromExist(object, fromObject, options) {
        return classTransformer.classToClassFromExist(object, fromObject, options);
      }
      exports.classToClassFromExist = classToClassFromExist;
      function serialize(object, options) {
        return classTransformer.serialize(object, options);
      }
      exports.serialize = serialize;
      function deserialize(cls, json, options) {
        return classTransformer.deserialize(cls, json, options);
      }
      exports.deserialize = deserialize;
      function deserializeArray(cls, json, options) {
        return classTransformer.deserializeArray(cls, json, options);
      }
      exports.deserializeArray = deserializeArray;
    }
  });

  // node_modules/reflect-metadata/Reflect.js
  var require_Reflect = __commonJS({
    "node_modules/reflect-metadata/Reflect.js"() {
      var Reflect2;
      (function(Reflect3) {
        (function(factory) {
          var root = typeof globalThis === "object" ? globalThis : typeof global === "object" ? global : typeof self === "object" ? self : typeof this === "object" ? this : sloppyModeThis();
          var exporter = makeExporter(Reflect3);
          if (typeof root.Reflect !== "undefined") {
            exporter = makeExporter(root.Reflect, exporter);
          }
          factory(exporter, root);
          if (typeof root.Reflect === "undefined") {
            root.Reflect = Reflect3;
          }
          function makeExporter(target, previous) {
            return function(key, value) {
              Object.defineProperty(target, key, { configurable: true, writable: true, value });
              if (previous)
                previous(key, value);
            };
          }
          function functionThis() {
            try {
              return Function("return this;")();
            } catch (_) {
            }
          }
          function indirectEvalThis() {
            try {
              return (void 0, eval)("(function() { return this; })()");
            } catch (_) {
            }
          }
          function sloppyModeThis() {
            return functionThis() || indirectEvalThis();
          }
        })(function(exporter, root) {
          var hasOwn = Object.prototype.hasOwnProperty;
          var supportsSymbol = typeof Symbol === "function";
          var toPrimitiveSymbol = supportsSymbol && typeof Symbol.toPrimitive !== "undefined" ? Symbol.toPrimitive : "@@toPrimitive";
          var iteratorSymbol = supportsSymbol && typeof Symbol.iterator !== "undefined" ? Symbol.iterator : "@@iterator";
          var supportsCreate = typeof Object.create === "function";
          var supportsProto = { __proto__: [] } instanceof Array;
          var downLevel = !supportsCreate && !supportsProto;
          var HashMap = {
            // create an object in dictionary mode (a.k.a. "slow" mode in v8)
            create: supportsCreate ? function() {
              return MakeDictionary(/* @__PURE__ */ Object.create(null));
            } : supportsProto ? function() {
              return MakeDictionary({ __proto__: null });
            } : function() {
              return MakeDictionary({});
            },
            has: downLevel ? function(map, key) {
              return hasOwn.call(map, key);
            } : function(map, key) {
              return key in map;
            },
            get: downLevel ? function(map, key) {
              return hasOwn.call(map, key) ? map[key] : void 0;
            } : function(map, key) {
              return map[key];
            }
          };
          var functionPrototype = Object.getPrototypeOf(Function);
          var _Map = typeof Map === "function" && typeof Map.prototype.entries === "function" ? Map : CreateMapPolyfill();
          var _Set = typeof Set === "function" && typeof Set.prototype.entries === "function" ? Set : CreateSetPolyfill();
          var _WeakMap = typeof WeakMap === "function" ? WeakMap : CreateWeakMapPolyfill();
          var registrySymbol = supportsSymbol ? Symbol.for("@reflect-metadata:registry") : void 0;
          var metadataRegistry = GetOrCreateMetadataRegistry();
          var metadataProvider = CreateMetadataProvider(metadataRegistry);
          function decorate(decorators, target, propertyKey, attributes) {
            if (!IsUndefined(propertyKey)) {
              if (!IsArray(decorators))
                throw new TypeError();
              if (!IsObject(target))
                throw new TypeError();
              if (!IsObject(attributes) && !IsUndefined(attributes) && !IsNull(attributes))
                throw new TypeError();
              if (IsNull(attributes))
                attributes = void 0;
              propertyKey = ToPropertyKey(propertyKey);
              return DecorateProperty(decorators, target, propertyKey, attributes);
            } else {
              if (!IsArray(decorators))
                throw new TypeError();
              if (!IsConstructor(target))
                throw new TypeError();
              return DecorateConstructor(decorators, target);
            }
          }
          exporter("decorate", decorate);
          function metadata(metadataKey, metadataValue) {
            function decorator(target, propertyKey) {
              if (!IsObject(target))
                throw new TypeError();
              if (!IsUndefined(propertyKey) && !IsPropertyKey(propertyKey))
                throw new TypeError();
              OrdinaryDefineOwnMetadata(metadataKey, metadataValue, target, propertyKey);
            }
            return decorator;
          }
          exporter("metadata", metadata);
          function defineMetadata(metadataKey, metadataValue, target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryDefineOwnMetadata(metadataKey, metadataValue, target, propertyKey);
          }
          exporter("defineMetadata", defineMetadata);
          function hasMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryHasMetadata(metadataKey, target, propertyKey);
          }
          exporter("hasMetadata", hasMetadata);
          function hasOwnMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryHasOwnMetadata(metadataKey, target, propertyKey);
          }
          exporter("hasOwnMetadata", hasOwnMetadata);
          function getMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryGetMetadata(metadataKey, target, propertyKey);
          }
          exporter("getMetadata", getMetadata);
          function getOwnMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryGetOwnMetadata(metadataKey, target, propertyKey);
          }
          exporter("getOwnMetadata", getOwnMetadata);
          function getMetadataKeys(target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryMetadataKeys(target, propertyKey);
          }
          exporter("getMetadataKeys", getMetadataKeys);
          function getOwnMetadataKeys(target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            return OrdinaryOwnMetadataKeys(target, propertyKey);
          }
          exporter("getOwnMetadataKeys", getOwnMetadataKeys);
          function deleteMetadata(metadataKey, target, propertyKey) {
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            if (!IsObject(target))
              throw new TypeError();
            if (!IsUndefined(propertyKey))
              propertyKey = ToPropertyKey(propertyKey);
            var provider = GetMetadataProvider(
              target,
              propertyKey,
              /*Create*/
              false
            );
            if (IsUndefined(provider))
              return false;
            return provider.OrdinaryDeleteMetadata(metadataKey, target, propertyKey);
          }
          exporter("deleteMetadata", deleteMetadata);
          function DecorateConstructor(decorators, target) {
            for (var i = decorators.length - 1; i >= 0; --i) {
              var decorator = decorators[i];
              var decorated = decorator(target);
              if (!IsUndefined(decorated) && !IsNull(decorated)) {
                if (!IsConstructor(decorated))
                  throw new TypeError();
                target = decorated;
              }
            }
            return target;
          }
          function DecorateProperty(decorators, target, propertyKey, descriptor) {
            for (var i = decorators.length - 1; i >= 0; --i) {
              var decorator = decorators[i];
              var decorated = decorator(target, propertyKey, descriptor);
              if (!IsUndefined(decorated) && !IsNull(decorated)) {
                if (!IsObject(decorated))
                  throw new TypeError();
                descriptor = decorated;
              }
            }
            return descriptor;
          }
          function OrdinaryHasMetadata(MetadataKey, O, P) {
            var hasOwn2 = OrdinaryHasOwnMetadata(MetadataKey, O, P);
            if (hasOwn2)
              return true;
            var parent = OrdinaryGetPrototypeOf(O);
            if (!IsNull(parent))
              return OrdinaryHasMetadata(MetadataKey, parent, P);
            return false;
          }
          function OrdinaryHasOwnMetadata(MetadataKey, O, P) {
            var provider = GetMetadataProvider(
              O,
              P,
              /*Create*/
              false
            );
            if (IsUndefined(provider))
              return false;
            return ToBoolean(provider.OrdinaryHasOwnMetadata(MetadataKey, O, P));
          }
          function OrdinaryGetMetadata(MetadataKey, O, P) {
            var hasOwn2 = OrdinaryHasOwnMetadata(MetadataKey, O, P);
            if (hasOwn2)
              return OrdinaryGetOwnMetadata(MetadataKey, O, P);
            var parent = OrdinaryGetPrototypeOf(O);
            if (!IsNull(parent))
              return OrdinaryGetMetadata(MetadataKey, parent, P);
            return void 0;
          }
          function OrdinaryGetOwnMetadata(MetadataKey, O, P) {
            var provider = GetMetadataProvider(
              O,
              P,
              /*Create*/
              false
            );
            if (IsUndefined(provider))
              return;
            return provider.OrdinaryGetOwnMetadata(MetadataKey, O, P);
          }
          function OrdinaryDefineOwnMetadata(MetadataKey, MetadataValue, O, P) {
            var provider = GetMetadataProvider(
              O,
              P,
              /*Create*/
              true
            );
            provider.OrdinaryDefineOwnMetadata(MetadataKey, MetadataValue, O, P);
          }
          function OrdinaryMetadataKeys(O, P) {
            var ownKeys = OrdinaryOwnMetadataKeys(O, P);
            var parent = OrdinaryGetPrototypeOf(O);
            if (parent === null)
              return ownKeys;
            var parentKeys = OrdinaryMetadataKeys(parent, P);
            if (parentKeys.length <= 0)
              return ownKeys;
            if (ownKeys.length <= 0)
              return parentKeys;
            var set = new _Set();
            var keys = [];
            for (var _i = 0, ownKeys_1 = ownKeys; _i < ownKeys_1.length; _i++) {
              var key = ownKeys_1[_i];
              var hasKey = set.has(key);
              if (!hasKey) {
                set.add(key);
                keys.push(key);
              }
            }
            for (var _a = 0, parentKeys_1 = parentKeys; _a < parentKeys_1.length; _a++) {
              var key = parentKeys_1[_a];
              var hasKey = set.has(key);
              if (!hasKey) {
                set.add(key);
                keys.push(key);
              }
            }
            return keys;
          }
          function OrdinaryOwnMetadataKeys(O, P) {
            var provider = GetMetadataProvider(
              O,
              P,
              /*create*/
              false
            );
            if (!provider) {
              return [];
            }
            return provider.OrdinaryOwnMetadataKeys(O, P);
          }
          function Type2(x) {
            if (x === null)
              return 1;
            switch (typeof x) {
              case "undefined":
                return 0;
              case "boolean":
                return 2;
              case "string":
                return 3;
              case "symbol":
                return 4;
              case "number":
                return 5;
              case "object":
                return x === null ? 1 : 6;
              default:
                return 6;
            }
          }
          function IsUndefined(x) {
            return x === void 0;
          }
          function IsNull(x) {
            return x === null;
          }
          function IsSymbol(x) {
            return typeof x === "symbol";
          }
          function IsObject(x) {
            return typeof x === "object" ? x !== null : typeof x === "function";
          }
          function ToPrimitive(input, PreferredType) {
            switch (Type2(input)) {
              case 0:
                return input;
              case 1:
                return input;
              case 2:
                return input;
              case 3:
                return input;
              case 4:
                return input;
              case 5:
                return input;
            }
            var hint = PreferredType === 3 ? "string" : PreferredType === 5 ? "number" : "default";
            var exoticToPrim = GetMethod(input, toPrimitiveSymbol);
            if (exoticToPrim !== void 0) {
              var result = exoticToPrim.call(input, hint);
              if (IsObject(result))
                throw new TypeError();
              return result;
            }
            return OrdinaryToPrimitive(input, hint === "default" ? "number" : hint);
          }
          function OrdinaryToPrimitive(O, hint) {
            if (hint === "string") {
              var toString_1 = O.toString;
              if (IsCallable(toString_1)) {
                var result = toString_1.call(O);
                if (!IsObject(result))
                  return result;
              }
              var valueOf = O.valueOf;
              if (IsCallable(valueOf)) {
                var result = valueOf.call(O);
                if (!IsObject(result))
                  return result;
              }
            } else {
              var valueOf = O.valueOf;
              if (IsCallable(valueOf)) {
                var result = valueOf.call(O);
                if (!IsObject(result))
                  return result;
              }
              var toString_2 = O.toString;
              if (IsCallable(toString_2)) {
                var result = toString_2.call(O);
                if (!IsObject(result))
                  return result;
              }
            }
            throw new TypeError();
          }
          function ToBoolean(argument) {
            return !!argument;
          }
          function ToString(argument) {
            return "" + argument;
          }
          function ToPropertyKey(argument) {
            var key = ToPrimitive(
              argument,
              3
              /* String */
            );
            if (IsSymbol(key))
              return key;
            return ToString(key);
          }
          function IsArray(argument) {
            return Array.isArray ? Array.isArray(argument) : argument instanceof Object ? argument instanceof Array : Object.prototype.toString.call(argument) === "[object Array]";
          }
          function IsCallable(argument) {
            return typeof argument === "function";
          }
          function IsConstructor(argument) {
            return typeof argument === "function";
          }
          function IsPropertyKey(argument) {
            switch (Type2(argument)) {
              case 3:
                return true;
              case 4:
                return true;
              default:
                return false;
            }
          }
          function SameValueZero(x, y) {
            return x === y || x !== x && y !== y;
          }
          function GetMethod(V, P) {
            var func = V[P];
            if (func === void 0 || func === null)
              return void 0;
            if (!IsCallable(func))
              throw new TypeError();
            return func;
          }
          function GetIterator(obj) {
            var method = GetMethod(obj, iteratorSymbol);
            if (!IsCallable(method))
              throw new TypeError();
            var iterator = method.call(obj);
            if (!IsObject(iterator))
              throw new TypeError();
            return iterator;
          }
          function IteratorValue(iterResult) {
            return iterResult.value;
          }
          function IteratorStep(iterator) {
            var result = iterator.next();
            return result.done ? false : result;
          }
          function IteratorClose(iterator) {
            var f = iterator["return"];
            if (f)
              f.call(iterator);
          }
          function OrdinaryGetPrototypeOf(O) {
            var proto = Object.getPrototypeOf(O);
            if (typeof O !== "function" || O === functionPrototype)
              return proto;
            if (proto !== functionPrototype)
              return proto;
            var prototype = O.prototype;
            var prototypeProto = prototype && Object.getPrototypeOf(prototype);
            if (prototypeProto == null || prototypeProto === Object.prototype)
              return proto;
            var constructor = prototypeProto.constructor;
            if (typeof constructor !== "function")
              return proto;
            if (constructor === O)
              return proto;
            return constructor;
          }
          function CreateMetadataRegistry() {
            var fallback;
            if (!IsUndefined(registrySymbol) && typeof root.Reflect !== "undefined" && !(registrySymbol in root.Reflect) && typeof root.Reflect.defineMetadata === "function") {
              fallback = CreateFallbackProvider(root.Reflect);
            }
            var first;
            var second;
            var rest;
            var targetProviderMap = new _WeakMap();
            var registry = {
              registerProvider,
              getProvider,
              setProvider
            };
            return registry;
            function registerProvider(provider) {
              if (!Object.isExtensible(registry)) {
                throw new Error("Cannot add provider to a frozen registry.");
              }
              switch (true) {
                case fallback === provider:
                  break;
                case IsUndefined(first):
                  first = provider;
                  break;
                case first === provider:
                  break;
                case IsUndefined(second):
                  second = provider;
                  break;
                case second === provider:
                  break;
                default:
                  if (rest === void 0)
                    rest = new _Set();
                  rest.add(provider);
                  break;
              }
            }
            function getProviderNoCache(O, P) {
              if (!IsUndefined(first)) {
                if (first.isProviderFor(O, P))
                  return first;
                if (!IsUndefined(second)) {
                  if (second.isProviderFor(O, P))
                    return first;
                  if (!IsUndefined(rest)) {
                    var iterator = GetIterator(rest);
                    while (true) {
                      var next = IteratorStep(iterator);
                      if (!next) {
                        return void 0;
                      }
                      var provider = IteratorValue(next);
                      if (provider.isProviderFor(O, P)) {
                        IteratorClose(iterator);
                        return provider;
                      }
                    }
                  }
                }
              }
              if (!IsUndefined(fallback) && fallback.isProviderFor(O, P)) {
                return fallback;
              }
              return void 0;
            }
            function getProvider(O, P) {
              var providerMap = targetProviderMap.get(O);
              var provider;
              if (!IsUndefined(providerMap)) {
                provider = providerMap.get(P);
              }
              if (!IsUndefined(provider)) {
                return provider;
              }
              provider = getProviderNoCache(O, P);
              if (!IsUndefined(provider)) {
                if (IsUndefined(providerMap)) {
                  providerMap = new _Map();
                  targetProviderMap.set(O, providerMap);
                }
                providerMap.set(P, provider);
              }
              return provider;
            }
            function hasProvider(provider) {
              if (IsUndefined(provider))
                throw new TypeError();
              return first === provider || second === provider || !IsUndefined(rest) && rest.has(provider);
            }
            function setProvider(O, P, provider) {
              if (!hasProvider(provider)) {
                throw new Error("Metadata provider not registered.");
              }
              var existingProvider = getProvider(O, P);
              if (existingProvider !== provider) {
                if (!IsUndefined(existingProvider)) {
                  return false;
                }
                var providerMap = targetProviderMap.get(O);
                if (IsUndefined(providerMap)) {
                  providerMap = new _Map();
                  targetProviderMap.set(O, providerMap);
                }
                providerMap.set(P, provider);
              }
              return true;
            }
          }
          function GetOrCreateMetadataRegistry() {
            var metadataRegistry2;
            if (!IsUndefined(registrySymbol) && IsObject(root.Reflect) && Object.isExtensible(root.Reflect)) {
              metadataRegistry2 = root.Reflect[registrySymbol];
            }
            if (IsUndefined(metadataRegistry2)) {
              metadataRegistry2 = CreateMetadataRegistry();
            }
            if (!IsUndefined(registrySymbol) && IsObject(root.Reflect) && Object.isExtensible(root.Reflect)) {
              Object.defineProperty(root.Reflect, registrySymbol, {
                enumerable: false,
                configurable: false,
                writable: false,
                value: metadataRegistry2
              });
            }
            return metadataRegistry2;
          }
          function CreateMetadataProvider(registry) {
            var metadata2 = new _WeakMap();
            var provider = {
              isProviderFor: function(O, P) {
                var targetMetadata = metadata2.get(O);
                if (IsUndefined(targetMetadata))
                  return false;
                return targetMetadata.has(P);
              },
              OrdinaryDefineOwnMetadata: OrdinaryDefineOwnMetadata2,
              OrdinaryHasOwnMetadata: OrdinaryHasOwnMetadata2,
              OrdinaryGetOwnMetadata: OrdinaryGetOwnMetadata2,
              OrdinaryOwnMetadataKeys: OrdinaryOwnMetadataKeys2,
              OrdinaryDeleteMetadata
            };
            metadataRegistry.registerProvider(provider);
            return provider;
            function GetOrCreateMetadataMap(O, P, Create) {
              var targetMetadata = metadata2.get(O);
              var createdTargetMetadata = false;
              if (IsUndefined(targetMetadata)) {
                if (!Create)
                  return void 0;
                targetMetadata = new _Map();
                metadata2.set(O, targetMetadata);
                createdTargetMetadata = true;
              }
              var metadataMap = targetMetadata.get(P);
              if (IsUndefined(metadataMap)) {
                if (!Create)
                  return void 0;
                metadataMap = new _Map();
                targetMetadata.set(P, metadataMap);
                if (!registry.setProvider(O, P, provider)) {
                  targetMetadata.delete(P);
                  if (createdTargetMetadata) {
                    metadata2.delete(O);
                  }
                  throw new Error("Wrong provider for target.");
                }
              }
              return metadataMap;
            }
            function OrdinaryHasOwnMetadata2(MetadataKey, O, P) {
              var metadataMap = GetOrCreateMetadataMap(
                O,
                P,
                /*Create*/
                false
              );
              if (IsUndefined(metadataMap))
                return false;
              return ToBoolean(metadataMap.has(MetadataKey));
            }
            function OrdinaryGetOwnMetadata2(MetadataKey, O, P) {
              var metadataMap = GetOrCreateMetadataMap(
                O,
                P,
                /*Create*/
                false
              );
              if (IsUndefined(metadataMap))
                return void 0;
              return metadataMap.get(MetadataKey);
            }
            function OrdinaryDefineOwnMetadata2(MetadataKey, MetadataValue, O, P) {
              var metadataMap = GetOrCreateMetadataMap(
                O,
                P,
                /*Create*/
                true
              );
              metadataMap.set(MetadataKey, MetadataValue);
            }
            function OrdinaryOwnMetadataKeys2(O, P) {
              var keys = [];
              var metadataMap = GetOrCreateMetadataMap(
                O,
                P,
                /*Create*/
                false
              );
              if (IsUndefined(metadataMap))
                return keys;
              var keysObj = metadataMap.keys();
              var iterator = GetIterator(keysObj);
              var k = 0;
              while (true) {
                var next = IteratorStep(iterator);
                if (!next) {
                  keys.length = k;
                  return keys;
                }
                var nextValue = IteratorValue(next);
                try {
                  keys[k] = nextValue;
                } catch (e) {
                  try {
                    IteratorClose(iterator);
                  } finally {
                    throw e;
                  }
                }
                k++;
              }
            }
            function OrdinaryDeleteMetadata(MetadataKey, O, P) {
              var metadataMap = GetOrCreateMetadataMap(
                O,
                P,
                /*Create*/
                false
              );
              if (IsUndefined(metadataMap))
                return false;
              if (!metadataMap.delete(MetadataKey))
                return false;
              if (metadataMap.size === 0) {
                var targetMetadata = metadata2.get(O);
                if (!IsUndefined(targetMetadata)) {
                  targetMetadata.delete(P);
                  if (targetMetadata.size === 0) {
                    metadata2.delete(targetMetadata);
                  }
                }
              }
              return true;
            }
          }
          function CreateFallbackProvider(reflect) {
            var defineMetadata2 = reflect.defineMetadata, hasOwnMetadata2 = reflect.hasOwnMetadata, getOwnMetadata2 = reflect.getOwnMetadata, getOwnMetadataKeys2 = reflect.getOwnMetadataKeys, deleteMetadata2 = reflect.deleteMetadata;
            var metadataOwner = new _WeakMap();
            var provider = {
              isProviderFor: function(O, P) {
                var metadataPropertySet = metadataOwner.get(O);
                if (!IsUndefined(metadataPropertySet) && metadataPropertySet.has(P)) {
                  return true;
                }
                if (getOwnMetadataKeys2(O, P).length) {
                  if (IsUndefined(metadataPropertySet)) {
                    metadataPropertySet = new _Set();
                    metadataOwner.set(O, metadataPropertySet);
                  }
                  metadataPropertySet.add(P);
                  return true;
                }
                return false;
              },
              OrdinaryDefineOwnMetadata: defineMetadata2,
              OrdinaryHasOwnMetadata: hasOwnMetadata2,
              OrdinaryGetOwnMetadata: getOwnMetadata2,
              OrdinaryOwnMetadataKeys: getOwnMetadataKeys2,
              OrdinaryDeleteMetadata: deleteMetadata2
            };
            return provider;
          }
          function GetMetadataProvider(O, P, Create) {
            var registeredProvider = metadataRegistry.getProvider(O, P);
            if (!IsUndefined(registeredProvider)) {
              return registeredProvider;
            }
            if (Create) {
              if (metadataRegistry.setProvider(O, P, metadataProvider)) {
                return metadataProvider;
              }
              throw new Error("Illegal state.");
            }
            return void 0;
          }
          function CreateMapPolyfill() {
            var cacheSentinel = {};
            var arraySentinel = [];
            var MapIterator = (
              /** @class */
              (function() {
                function MapIterator2(keys, values, selector) {
                  this._index = 0;
                  this._keys = keys;
                  this._values = values;
                  this._selector = selector;
                }
                MapIterator2.prototype["@@iterator"] = function() {
                  return this;
                };
                MapIterator2.prototype[iteratorSymbol] = function() {
                  return this;
                };
                MapIterator2.prototype.next = function() {
                  var index = this._index;
                  if (index >= 0 && index < this._keys.length) {
                    var result = this._selector(this._keys[index], this._values[index]);
                    if (index + 1 >= this._keys.length) {
                      this._index = -1;
                      this._keys = arraySentinel;
                      this._values = arraySentinel;
                    } else {
                      this._index++;
                    }
                    return { value: result, done: false };
                  }
                  return { value: void 0, done: true };
                };
                MapIterator2.prototype.throw = function(error) {
                  if (this._index >= 0) {
                    this._index = -1;
                    this._keys = arraySentinel;
                    this._values = arraySentinel;
                  }
                  throw error;
                };
                MapIterator2.prototype.return = function(value) {
                  if (this._index >= 0) {
                    this._index = -1;
                    this._keys = arraySentinel;
                    this._values = arraySentinel;
                  }
                  return { value, done: true };
                };
                return MapIterator2;
              })()
            );
            var Map2 = (
              /** @class */
              (function() {
                function Map3() {
                  this._keys = [];
                  this._values = [];
                  this._cacheKey = cacheSentinel;
                  this._cacheIndex = -2;
                }
                Object.defineProperty(Map3.prototype, "size", {
                  get: function() {
                    return this._keys.length;
                  },
                  enumerable: true,
                  configurable: true
                });
                Map3.prototype.has = function(key) {
                  return this._find(
                    key,
                    /*insert*/
                    false
                  ) >= 0;
                };
                Map3.prototype.get = function(key) {
                  var index = this._find(
                    key,
                    /*insert*/
                    false
                  );
                  return index >= 0 ? this._values[index] : void 0;
                };
                Map3.prototype.set = function(key, value) {
                  var index = this._find(
                    key,
                    /*insert*/
                    true
                  );
                  this._values[index] = value;
                  return this;
                };
                Map3.prototype.delete = function(key) {
                  var index = this._find(
                    key,
                    /*insert*/
                    false
                  );
                  if (index >= 0) {
                    var size = this._keys.length;
                    for (var i = index + 1; i < size; i++) {
                      this._keys[i - 1] = this._keys[i];
                      this._values[i - 1] = this._values[i];
                    }
                    this._keys.length--;
                    this._values.length--;
                    if (SameValueZero(key, this._cacheKey)) {
                      this._cacheKey = cacheSentinel;
                      this._cacheIndex = -2;
                    }
                    return true;
                  }
                  return false;
                };
                Map3.prototype.clear = function() {
                  this._keys.length = 0;
                  this._values.length = 0;
                  this._cacheKey = cacheSentinel;
                  this._cacheIndex = -2;
                };
                Map3.prototype.keys = function() {
                  return new MapIterator(this._keys, this._values, getKey);
                };
                Map3.prototype.values = function() {
                  return new MapIterator(this._keys, this._values, getValue);
                };
                Map3.prototype.entries = function() {
                  return new MapIterator(this._keys, this._values, getEntry);
                };
                Map3.prototype["@@iterator"] = function() {
                  return this.entries();
                };
                Map3.prototype[iteratorSymbol] = function() {
                  return this.entries();
                };
                Map3.prototype._find = function(key, insert) {
                  if (!SameValueZero(this._cacheKey, key)) {
                    this._cacheIndex = -1;
                    for (var i = 0; i < this._keys.length; i++) {
                      if (SameValueZero(this._keys[i], key)) {
                        this._cacheIndex = i;
                        break;
                      }
                    }
                  }
                  if (this._cacheIndex < 0 && insert) {
                    this._cacheIndex = this._keys.length;
                    this._keys.push(key);
                    this._values.push(void 0);
                  }
                  return this._cacheIndex;
                };
                return Map3;
              })()
            );
            return Map2;
            function getKey(key, _) {
              return key;
            }
            function getValue(_, value) {
              return value;
            }
            function getEntry(key, value) {
              return [key, value];
            }
          }
          function CreateSetPolyfill() {
            var Set2 = (
              /** @class */
              (function() {
                function Set3() {
                  this._map = new _Map();
                }
                Object.defineProperty(Set3.prototype, "size", {
                  get: function() {
                    return this._map.size;
                  },
                  enumerable: true,
                  configurable: true
                });
                Set3.prototype.has = function(value) {
                  return this._map.has(value);
                };
                Set3.prototype.add = function(value) {
                  return this._map.set(value, value), this;
                };
                Set3.prototype.delete = function(value) {
                  return this._map.delete(value);
                };
                Set3.prototype.clear = function() {
                  this._map.clear();
                };
                Set3.prototype.keys = function() {
                  return this._map.keys();
                };
                Set3.prototype.values = function() {
                  return this._map.keys();
                };
                Set3.prototype.entries = function() {
                  return this._map.entries();
                };
                Set3.prototype["@@iterator"] = function() {
                  return this.keys();
                };
                Set3.prototype[iteratorSymbol] = function() {
                  return this.keys();
                };
                return Set3;
              })()
            );
            return Set2;
          }
          function CreateWeakMapPolyfill() {
            var UUID_SIZE = 16;
            var keys = HashMap.create();
            var rootKey = CreateUniqueKey();
            return (
              /** @class */
              (function() {
                function WeakMap2() {
                  this._key = CreateUniqueKey();
                }
                WeakMap2.prototype.has = function(target) {
                  var table = GetOrCreateWeakMapTable(
                    target,
                    /*create*/
                    false
                  );
                  return table !== void 0 ? HashMap.has(table, this._key) : false;
                };
                WeakMap2.prototype.get = function(target) {
                  var table = GetOrCreateWeakMapTable(
                    target,
                    /*create*/
                    false
                  );
                  return table !== void 0 ? HashMap.get(table, this._key) : void 0;
                };
                WeakMap2.prototype.set = function(target, value) {
                  var table = GetOrCreateWeakMapTable(
                    target,
                    /*create*/
                    true
                  );
                  table[this._key] = value;
                  return this;
                };
                WeakMap2.prototype.delete = function(target) {
                  var table = GetOrCreateWeakMapTable(
                    target,
                    /*create*/
                    false
                  );
                  return table !== void 0 ? delete table[this._key] : false;
                };
                WeakMap2.prototype.clear = function() {
                  this._key = CreateUniqueKey();
                };
                return WeakMap2;
              })()
            );
            function CreateUniqueKey() {
              var key;
              do
                key = "@@WeakMap@@" + CreateUUID();
              while (HashMap.has(keys, key));
              keys[key] = true;
              return key;
            }
            function GetOrCreateWeakMapTable(target, create) {
              if (!hasOwn.call(target, rootKey)) {
                if (!create)
                  return void 0;
                Object.defineProperty(target, rootKey, { value: HashMap.create() });
              }
              return target[rootKey];
            }
            function FillRandomBytes(buffer, size) {
              for (var i = 0; i < size; ++i)
                buffer[i] = Math.random() * 255 | 0;
              return buffer;
            }
            function GenRandomBytes(size) {
              if (typeof Uint8Array === "function") {
                var array = new Uint8Array(size);
                if (typeof crypto !== "undefined") {
                  crypto.getRandomValues(array);
                } else if (typeof msCrypto !== "undefined") {
                  msCrypto.getRandomValues(array);
                } else {
                  FillRandomBytes(array, size);
                }
                return array;
              }
              return FillRandomBytes(new Array(size), size);
            }
            function CreateUUID() {
              var data = GenRandomBytes(UUID_SIZE);
              data[6] = data[6] & 79 | 64;
              data[8] = data[8] & 191 | 128;
              var result = "";
              for (var offset = 0; offset < UUID_SIZE; ++offset) {
                var byte = data[offset];
                if (offset === 4 || offset === 6 || offset === 8)
                  result += "-";
                if (byte < 16)
                  result += "0";
                result += byte.toString(16).toLowerCase();
              }
              return result;
            }
          }
          function MakeDictionary(obj) {
            obj.__ = void 0;
            delete obj.__;
            return obj;
          }
        });
      })(Reflect2 || (Reflect2 = {}));
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/messages.js
  var require_messages = __commonJS({
    "node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/messages.js"(exports) {
      "use strict";
      var __decorate2 = exports && exports.__decorate || function(decorators, target, key, desc) {
        var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
        if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
        else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
        return c > 3 && r && Object.defineProperty(target, key, r), r;
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.TestRunStarted = exports.TestRunFinished = exports.TestCaseStarted = exports.TestCaseFinished = exports.TestStep = exports.StepMatchArgumentsList = exports.StepMatchArgument = exports.Group = exports.TestCase = exports.StepDefinitionPattern = exports.StepDefinition = exports.JavaStackTraceElement = exports.JavaMethod = exports.SourceReference = exports.Source = exports.PickleTag = exports.PickleTableRow = exports.PickleTableCell = exports.PickleTable = exports.PickleStepArgument = exports.PickleStep = exports.PickleDocString = exports.Pickle = exports.ParseError = exports.ParameterType = exports.Product = exports.Git = exports.Ci = exports.Meta = exports.Location = exports.Hook = exports.Tag = exports.TableRow = exports.TableCell = exports.Step = exports.Scenario = exports.RuleChild = exports.Rule = exports.FeatureChild = exports.Feature = exports.Examples = exports.DocString = exports.DataTable = exports.Comment = exports.Background = exports.GherkinDocument = exports.Exception = exports.Envelope = exports.Duration = exports.Attachment = void 0;
      exports.TestStepResultStatus = exports.StepKeywordType = exports.StepDefinitionPatternType = exports.SourceMediaType = exports.PickleStepType = exports.AttachmentContentEncoding = exports.UndefinedParameterType = exports.Timestamp = exports.TestStepStarted = exports.TestStepResult = exports.TestStepFinished = void 0;
      var class_transformer_1 = require_cjs();
      require_Reflect();
      var Attachment2 = (
        /** @class */
        (function() {
          function Attachment3() {
            this.body = "";
            this.contentEncoding = AttachmentContentEncoding2.IDENTITY;
            this.mediaType = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Source2;
            })
          ], Attachment3.prototype, "source", void 0);
          return Attachment3;
        })()
      );
      exports.Attachment = Attachment2;
      var Duration2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function Duration3() {
            this.seconds = 0;
            this.nanos = 0;
          }
          return Duration3;
        })()
      );
      exports.Duration = Duration2;
      var Envelope2 = (
        /** @class */
        (function() {
          function Envelope3() {
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Attachment2;
            })
          ], Envelope3.prototype, "attachment", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return GherkinDocument2;
            })
          ], Envelope3.prototype, "gherkinDocument", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Hook2;
            })
          ], Envelope3.prototype, "hook", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Meta2;
            })
          ], Envelope3.prototype, "meta", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return ParameterType3;
            })
          ], Envelope3.prototype, "parameterType", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return ParseError2;
            })
          ], Envelope3.prototype, "parseError", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Pickle2;
            })
          ], Envelope3.prototype, "pickle", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Source2;
            })
          ], Envelope3.prototype, "source", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return StepDefinition2;
            })
          ], Envelope3.prototype, "stepDefinition", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestCase2;
            })
          ], Envelope3.prototype, "testCase", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestCaseFinished2;
            })
          ], Envelope3.prototype, "testCaseFinished", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestCaseStarted2;
            })
          ], Envelope3.prototype, "testCaseStarted", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestRunFinished2;
            })
          ], Envelope3.prototype, "testRunFinished", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestRunStarted2;
            })
          ], Envelope3.prototype, "testRunStarted", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestStepFinished2;
            })
          ], Envelope3.prototype, "testStepFinished", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestStepStarted2;
            })
          ], Envelope3.prototype, "testStepStarted", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return UndefinedParameterType2;
            })
          ], Envelope3.prototype, "undefinedParameterType", void 0);
          return Envelope3;
        })()
      );
      exports.Envelope = Envelope2;
      var Exception2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function Exception3() {
            this.type = "";
          }
          return Exception3;
        })()
      );
      exports.Exception = Exception2;
      var GherkinDocument2 = (
        /** @class */
        (function() {
          function GherkinDocument3() {
            this.comments = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Feature2;
            })
          ], GherkinDocument3.prototype, "feature", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Comment2;
            })
          ], GherkinDocument3.prototype, "comments", void 0);
          return GherkinDocument3;
        })()
      );
      exports.GherkinDocument = GherkinDocument2;
      var Background2 = (
        /** @class */
        (function() {
          function Background3() {
            this.location = new Location2();
            this.keyword = "";
            this.name = "";
            this.description = "";
            this.steps = [];
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Background3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Step2;
            })
          ], Background3.prototype, "steps", void 0);
          return Background3;
        })()
      );
      exports.Background = Background2;
      var Comment2 = (
        /** @class */
        (function() {
          function Comment3() {
            this.location = new Location2();
            this.text = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Comment3.prototype, "location", void 0);
          return Comment3;
        })()
      );
      exports.Comment = Comment2;
      var DataTable2 = (
        /** @class */
        (function() {
          function DataTable3() {
            this.location = new Location2();
            this.rows = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], DataTable3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TableRow2;
            })
          ], DataTable3.prototype, "rows", void 0);
          return DataTable3;
        })()
      );
      exports.DataTable = DataTable2;
      var DocString2 = (
        /** @class */
        (function() {
          function DocString3() {
            this.location = new Location2();
            this.content = "";
            this.delimiter = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], DocString3.prototype, "location", void 0);
          return DocString3;
        })()
      );
      exports.DocString = DocString2;
      var Examples2 = (
        /** @class */
        (function() {
          function Examples3() {
            this.location = new Location2();
            this.tags = [];
            this.keyword = "";
            this.name = "";
            this.description = "";
            this.tableBody = [];
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Examples3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Tag2;
            })
          ], Examples3.prototype, "tags", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TableRow2;
            })
          ], Examples3.prototype, "tableHeader", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TableRow2;
            })
          ], Examples3.prototype, "tableBody", void 0);
          return Examples3;
        })()
      );
      exports.Examples = Examples2;
      var Feature2 = (
        /** @class */
        (function() {
          function Feature3() {
            this.location = new Location2();
            this.tags = [];
            this.language = "";
            this.keyword = "";
            this.name = "";
            this.description = "";
            this.children = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Feature3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Tag2;
            })
          ], Feature3.prototype, "tags", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return FeatureChild2;
            })
          ], Feature3.prototype, "children", void 0);
          return Feature3;
        })()
      );
      exports.Feature = Feature2;
      var FeatureChild2 = (
        /** @class */
        (function() {
          function FeatureChild3() {
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Rule2;
            })
          ], FeatureChild3.prototype, "rule", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Background2;
            })
          ], FeatureChild3.prototype, "background", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Scenario2;
            })
          ], FeatureChild3.prototype, "scenario", void 0);
          return FeatureChild3;
        })()
      );
      exports.FeatureChild = FeatureChild2;
      var Rule2 = (
        /** @class */
        (function() {
          function Rule3() {
            this.location = new Location2();
            this.tags = [];
            this.keyword = "";
            this.name = "";
            this.description = "";
            this.children = [];
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Rule3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Tag2;
            })
          ], Rule3.prototype, "tags", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return RuleChild2;
            })
          ], Rule3.prototype, "children", void 0);
          return Rule3;
        })()
      );
      exports.Rule = Rule2;
      var RuleChild2 = (
        /** @class */
        (function() {
          function RuleChild3() {
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Background2;
            })
          ], RuleChild3.prototype, "background", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Scenario2;
            })
          ], RuleChild3.prototype, "scenario", void 0);
          return RuleChild3;
        })()
      );
      exports.RuleChild = RuleChild2;
      var Scenario2 = (
        /** @class */
        (function() {
          function Scenario3() {
            this.location = new Location2();
            this.tags = [];
            this.keyword = "";
            this.name = "";
            this.description = "";
            this.steps = [];
            this.examples = [];
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Scenario3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Tag2;
            })
          ], Scenario3.prototype, "tags", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Step2;
            })
          ], Scenario3.prototype, "steps", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Examples2;
            })
          ], Scenario3.prototype, "examples", void 0);
          return Scenario3;
        })()
      );
      exports.Scenario = Scenario2;
      var Step2 = (
        /** @class */
        (function() {
          function Step3() {
            this.location = new Location2();
            this.keyword = "";
            this.text = "";
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Step3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return DocString2;
            })
          ], Step3.prototype, "docString", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return DataTable2;
            })
          ], Step3.prototype, "dataTable", void 0);
          return Step3;
        })()
      );
      exports.Step = Step2;
      var TableCell2 = (
        /** @class */
        (function() {
          function TableCell3() {
            this.location = new Location2();
            this.value = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], TableCell3.prototype, "location", void 0);
          return TableCell3;
        })()
      );
      exports.TableCell = TableCell2;
      var TableRow2 = (
        /** @class */
        (function() {
          function TableRow3() {
            this.location = new Location2();
            this.cells = [];
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], TableRow3.prototype, "location", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TableCell2;
            })
          ], TableRow3.prototype, "cells", void 0);
          return TableRow3;
        })()
      );
      exports.TableRow = TableRow2;
      var Tag2 = (
        /** @class */
        (function() {
          function Tag3() {
            this.location = new Location2();
            this.name = "";
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], Tag3.prototype, "location", void 0);
          return Tag3;
        })()
      );
      exports.Tag = Tag2;
      var Hook2 = (
        /** @class */
        (function() {
          function Hook3() {
            this.id = "";
            this.sourceReference = new SourceReference2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return SourceReference2;
            })
          ], Hook3.prototype, "sourceReference", void 0);
          return Hook3;
        })()
      );
      exports.Hook = Hook2;
      var Location2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function Location3() {
            this.line = 0;
          }
          return Location3;
        })()
      );
      exports.Location = Location2;
      var Meta2 = (
        /** @class */
        (function() {
          function Meta3() {
            this.protocolVersion = "";
            this.implementation = new Product2();
            this.runtime = new Product2();
            this.os = new Product2();
            this.cpu = new Product2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Product2;
            })
          ], Meta3.prototype, "implementation", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Product2;
            })
          ], Meta3.prototype, "runtime", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Product2;
            })
          ], Meta3.prototype, "os", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Product2;
            })
          ], Meta3.prototype, "cpu", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Ci2;
            })
          ], Meta3.prototype, "ci", void 0);
          return Meta3;
        })()
      );
      exports.Meta = Meta2;
      var Ci2 = (
        /** @class */
        (function() {
          function Ci3() {
            this.name = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Git2;
            })
          ], Ci3.prototype, "git", void 0);
          return Ci3;
        })()
      );
      exports.Ci = Ci2;
      var Git2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function Git3() {
            this.remote = "";
            this.revision = "";
          }
          return Git3;
        })()
      );
      exports.Git = Git2;
      var Product2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function Product3() {
            this.name = "";
          }
          return Product3;
        })()
      );
      exports.Product = Product2;
      var ParameterType3 = (
        /** @class */
        (function() {
          function ParameterType4() {
            this.name = "";
            this.regularExpressions = [];
            this.preferForRegularExpressionMatch = false;
            this.useForSnippets = false;
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return SourceReference2;
            })
          ], ParameterType4.prototype, "sourceReference", void 0);
          return ParameterType4;
        })()
      );
      exports.ParameterType = ParameterType3;
      var ParseError2 = (
        /** @class */
        (function() {
          function ParseError3() {
            this.source = new SourceReference2();
            this.message = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return SourceReference2;
            })
          ], ParseError3.prototype, "source", void 0);
          return ParseError3;
        })()
      );
      exports.ParseError = ParseError2;
      var Pickle2 = (
        /** @class */
        (function() {
          function Pickle3() {
            this.id = "";
            this.uri = "";
            this.name = "";
            this.language = "";
            this.steps = [];
            this.tags = [];
            this.astNodeIds = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return PickleStep2;
            })
          ], Pickle3.prototype, "steps", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return PickleTag2;
            })
          ], Pickle3.prototype, "tags", void 0);
          return Pickle3;
        })()
      );
      exports.Pickle = Pickle2;
      var PickleDocString2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function PickleDocString3() {
            this.content = "";
          }
          return PickleDocString3;
        })()
      );
      exports.PickleDocString = PickleDocString2;
      var PickleStep2 = (
        /** @class */
        (function() {
          function PickleStep3() {
            this.astNodeIds = [];
            this.id = "";
            this.text = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return PickleStepArgument2;
            })
          ], PickleStep3.prototype, "argument", void 0);
          return PickleStep3;
        })()
      );
      exports.PickleStep = PickleStep2;
      var PickleStepArgument2 = (
        /** @class */
        (function() {
          function PickleStepArgument3() {
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return PickleDocString2;
            })
          ], PickleStepArgument3.prototype, "docString", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return PickleTable2;
            })
          ], PickleStepArgument3.prototype, "dataTable", void 0);
          return PickleStepArgument3;
        })()
      );
      exports.PickleStepArgument = PickleStepArgument2;
      var PickleTable2 = (
        /** @class */
        (function() {
          function PickleTable3() {
            this.rows = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return PickleTableRow2;
            })
          ], PickleTable3.prototype, "rows", void 0);
          return PickleTable3;
        })()
      );
      exports.PickleTable = PickleTable2;
      var PickleTableCell2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function PickleTableCell3() {
            this.value = "";
          }
          return PickleTableCell3;
        })()
      );
      exports.PickleTableCell = PickleTableCell2;
      var PickleTableRow2 = (
        /** @class */
        (function() {
          function PickleTableRow3() {
            this.cells = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return PickleTableCell2;
            })
          ], PickleTableRow3.prototype, "cells", void 0);
          return PickleTableRow3;
        })()
      );
      exports.PickleTableRow = PickleTableRow2;
      var PickleTag2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function PickleTag3() {
            this.name = "";
            this.astNodeId = "";
          }
          return PickleTag3;
        })()
      );
      exports.PickleTag = PickleTag2;
      var Source2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function Source3() {
            this.uri = "";
            this.data = "";
            this.mediaType = SourceMediaType2.TEXT_X_CUCUMBER_GHERKIN_PLAIN;
          }
          return Source3;
        })()
      );
      exports.Source = Source2;
      var SourceReference2 = (
        /** @class */
        (function() {
          function SourceReference3() {
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return JavaMethod2;
            })
          ], SourceReference3.prototype, "javaMethod", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return JavaStackTraceElement2;
            })
          ], SourceReference3.prototype, "javaStackTraceElement", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Location2;
            })
          ], SourceReference3.prototype, "location", void 0);
          return SourceReference3;
        })()
      );
      exports.SourceReference = SourceReference2;
      var JavaMethod2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function JavaMethod3() {
            this.className = "";
            this.methodName = "";
            this.methodParameterTypes = [];
          }
          return JavaMethod3;
        })()
      );
      exports.JavaMethod = JavaMethod2;
      var JavaStackTraceElement2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function JavaStackTraceElement3() {
            this.className = "";
            this.fileName = "";
            this.methodName = "";
          }
          return JavaStackTraceElement3;
        })()
      );
      exports.JavaStackTraceElement = JavaStackTraceElement2;
      var StepDefinition2 = (
        /** @class */
        (function() {
          function StepDefinition3() {
            this.id = "";
            this.pattern = new StepDefinitionPattern2();
            this.sourceReference = new SourceReference2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return StepDefinitionPattern2;
            })
          ], StepDefinition3.prototype, "pattern", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return SourceReference2;
            })
          ], StepDefinition3.prototype, "sourceReference", void 0);
          return StepDefinition3;
        })()
      );
      exports.StepDefinition = StepDefinition2;
      var StepDefinitionPattern2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function StepDefinitionPattern3() {
            this.source = "";
            this.type = StepDefinitionPatternType2.CUCUMBER_EXPRESSION;
          }
          return StepDefinitionPattern3;
        })()
      );
      exports.StepDefinitionPattern = StepDefinitionPattern2;
      var TestCase2 = (
        /** @class */
        (function() {
          function TestCase3() {
            this.id = "";
            this.pickleId = "";
            this.testSteps = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestStep2;
            })
          ], TestCase3.prototype, "testSteps", void 0);
          return TestCase3;
        })()
      );
      exports.TestCase = TestCase2;
      var Group3 = (
        /** @class */
        (function() {
          function Group4() {
            this.children = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Group4;
            })
          ], Group4.prototype, "children", void 0);
          return Group4;
        })()
      );
      exports.Group = Group3;
      var StepMatchArgument2 = (
        /** @class */
        (function() {
          function StepMatchArgument3() {
            this.group = new Group3();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Group3;
            })
          ], StepMatchArgument3.prototype, "group", void 0);
          return StepMatchArgument3;
        })()
      );
      exports.StepMatchArgument = StepMatchArgument2;
      var StepMatchArgumentsList2 = (
        /** @class */
        (function() {
          function StepMatchArgumentsList3() {
            this.stepMatchArguments = [];
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return StepMatchArgument2;
            })
          ], StepMatchArgumentsList3.prototype, "stepMatchArguments", void 0);
          return StepMatchArgumentsList3;
        })()
      );
      exports.StepMatchArgumentsList = StepMatchArgumentsList2;
      var TestStep2 = (
        /** @class */
        (function() {
          function TestStep3() {
            this.id = "";
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return StepMatchArgumentsList2;
            })
          ], TestStep3.prototype, "stepMatchArgumentsLists", void 0);
          return TestStep3;
        })()
      );
      exports.TestStep = TestStep2;
      var TestCaseFinished2 = (
        /** @class */
        (function() {
          function TestCaseFinished3() {
            this.testCaseStartedId = "";
            this.timestamp = new Timestamp2();
            this.willBeRetried = false;
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Timestamp2;
            })
          ], TestCaseFinished3.prototype, "timestamp", void 0);
          return TestCaseFinished3;
        })()
      );
      exports.TestCaseFinished = TestCaseFinished2;
      var TestCaseStarted2 = (
        /** @class */
        (function() {
          function TestCaseStarted3() {
            this.attempt = 0;
            this.id = "";
            this.testCaseId = "";
            this.timestamp = new Timestamp2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Timestamp2;
            })
          ], TestCaseStarted3.prototype, "timestamp", void 0);
          return TestCaseStarted3;
        })()
      );
      exports.TestCaseStarted = TestCaseStarted2;
      var TestRunFinished2 = (
        /** @class */
        (function() {
          function TestRunFinished3() {
            this.success = false;
            this.timestamp = new Timestamp2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Timestamp2;
            })
          ], TestRunFinished3.prototype, "timestamp", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Exception2;
            })
          ], TestRunFinished3.prototype, "exception", void 0);
          return TestRunFinished3;
        })()
      );
      exports.TestRunFinished = TestRunFinished2;
      var TestRunStarted2 = (
        /** @class */
        (function() {
          function TestRunStarted3() {
            this.timestamp = new Timestamp2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Timestamp2;
            })
          ], TestRunStarted3.prototype, "timestamp", void 0);
          return TestRunStarted3;
        })()
      );
      exports.TestRunStarted = TestRunStarted2;
      var TestStepFinished2 = (
        /** @class */
        (function() {
          function TestStepFinished3() {
            this.testCaseStartedId = "";
            this.testStepId = "";
            this.testStepResult = new TestStepResult2();
            this.timestamp = new Timestamp2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return TestStepResult2;
            })
          ], TestStepFinished3.prototype, "testStepResult", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Timestamp2;
            })
          ], TestStepFinished3.prototype, "timestamp", void 0);
          return TestStepFinished3;
        })()
      );
      exports.TestStepFinished = TestStepFinished2;
      var TestStepResult2 = (
        /** @class */
        (function() {
          function TestStepResult3() {
            this.duration = new Duration2();
            this.status = TestStepResultStatus2.UNKNOWN;
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Duration2;
            })
          ], TestStepResult3.prototype, "duration", void 0);
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Exception2;
            })
          ], TestStepResult3.prototype, "exception", void 0);
          return TestStepResult3;
        })()
      );
      exports.TestStepResult = TestStepResult2;
      var TestStepStarted2 = (
        /** @class */
        (function() {
          function TestStepStarted3() {
            this.testCaseStartedId = "";
            this.testStepId = "";
            this.timestamp = new Timestamp2();
          }
          __decorate2([
            (0, class_transformer_1.Type)(function() {
              return Timestamp2;
            })
          ], TestStepStarted3.prototype, "timestamp", void 0);
          return TestStepStarted3;
        })()
      );
      exports.TestStepStarted = TestStepStarted2;
      var Timestamp2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function Timestamp3() {
            this.seconds = 0;
            this.nanos = 0;
          }
          return Timestamp3;
        })()
      );
      exports.Timestamp = Timestamp2;
      var UndefinedParameterType2 = (
        /** @class */
        /* @__PURE__ */ (function() {
          function UndefinedParameterType3() {
            this.expression = "";
            this.name = "";
          }
          return UndefinedParameterType3;
        })()
      );
      exports.UndefinedParameterType = UndefinedParameterType2;
      var AttachmentContentEncoding2;
      (function(AttachmentContentEncoding3) {
        AttachmentContentEncoding3["IDENTITY"] = "IDENTITY";
        AttachmentContentEncoding3["BASE64"] = "BASE64";
      })(AttachmentContentEncoding2 || (exports.AttachmentContentEncoding = AttachmentContentEncoding2 = {}));
      var PickleStepType2;
      (function(PickleStepType3) {
        PickleStepType3["UNKNOWN"] = "Unknown";
        PickleStepType3["CONTEXT"] = "Context";
        PickleStepType3["ACTION"] = "Action";
        PickleStepType3["OUTCOME"] = "Outcome";
      })(PickleStepType2 || (exports.PickleStepType = PickleStepType2 = {}));
      var SourceMediaType2;
      (function(SourceMediaType3) {
        SourceMediaType3["TEXT_X_CUCUMBER_GHERKIN_PLAIN"] = "text/x.cucumber.gherkin+plain";
        SourceMediaType3["TEXT_X_CUCUMBER_GHERKIN_MARKDOWN"] = "text/x.cucumber.gherkin+markdown";
      })(SourceMediaType2 || (exports.SourceMediaType = SourceMediaType2 = {}));
      var StepDefinitionPatternType2;
      (function(StepDefinitionPatternType3) {
        StepDefinitionPatternType3["CUCUMBER_EXPRESSION"] = "CUCUMBER_EXPRESSION";
        StepDefinitionPatternType3["REGULAR_EXPRESSION"] = "REGULAR_EXPRESSION";
      })(StepDefinitionPatternType2 || (exports.StepDefinitionPatternType = StepDefinitionPatternType2 = {}));
      var StepKeywordType2;
      (function(StepKeywordType3) {
        StepKeywordType3["UNKNOWN"] = "Unknown";
        StepKeywordType3["CONTEXT"] = "Context";
        StepKeywordType3["ACTION"] = "Action";
        StepKeywordType3["OUTCOME"] = "Outcome";
        StepKeywordType3["CONJUNCTION"] = "Conjunction";
      })(StepKeywordType2 || (exports.StepKeywordType = StepKeywordType2 = {}));
      var TestStepResultStatus2;
      (function(TestStepResultStatus3) {
        TestStepResultStatus3["UNKNOWN"] = "UNKNOWN";
        TestStepResultStatus3["PASSED"] = "PASSED";
        TestStepResultStatus3["SKIPPED"] = "SKIPPED";
        TestStepResultStatus3["PENDING"] = "PENDING";
        TestStepResultStatus3["UNDEFINED"] = "UNDEFINED";
        TestStepResultStatus3["AMBIGUOUS"] = "AMBIGUOUS";
        TestStepResultStatus3["FAILED"] = "FAILED";
      })(TestStepResultStatus2 || (exports.TestStepResultStatus = TestStepResultStatus2 = {}));
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/parseEnvelope.js
  var require_parseEnvelope = __commonJS({
    "node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/parseEnvelope.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.parseEnvelope = parseEnvelope2;
      var messages_js_1 = require_messages();
      var class_transformer_1 = require_cjs();
      function parseEnvelope2(json) {
        var plain = JSON.parse(json);
        return (0, class_transformer_1.plainToClass)(messages_js_1.Envelope, plain);
      }
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/getWorstTestStepResult.js
  var require_getWorstTestStepResult = __commonJS({
    "node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/getWorstTestStepResult.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.getWorstTestStepResult = getWorstTestStepResult2;
      var messages_js_1 = require_messages();
      var TimeConversion_js_1 = require_TimeConversion();
      function getWorstTestStepResult2(testStepResults) {
        return testStepResults.slice().sort(function(r1, r2) {
          return ordinal(r2.status) - ordinal(r1.status);
        })[0] || {
          status: messages_js_1.TestStepResultStatus.UNKNOWN,
          duration: (0, TimeConversion_js_1.millisecondsToDuration)(0)
        };
      }
      function ordinal(status) {
        return [
          messages_js_1.TestStepResultStatus.UNKNOWN,
          messages_js_1.TestStepResultStatus.PASSED,
          messages_js_1.TestStepResultStatus.SKIPPED,
          messages_js_1.TestStepResultStatus.PENDING,
          messages_js_1.TestStepResultStatus.UNDEFINED,
          messages_js_1.TestStepResultStatus.AMBIGUOUS,
          messages_js_1.TestStepResultStatus.FAILED
        ].indexOf(status);
      }
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/version.js
  var require_version = __commonJS({
    "node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/version.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.version = void 0;
      exports.version = "26.0.1";
    }
  });

  // node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/index.js
  var require_src = __commonJS({
    "node_modules/@cucumber/gherkin/node_modules/@cucumber/messages/dist/cjs/src/index.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        var desc = Object.getOwnPropertyDescriptor(m, k);
        if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
          desc = { enumerable: true, get: function() {
            return m[k];
          } };
        }
        Object.defineProperty(o, k2, desc);
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __setModuleDefault = exports && exports.__setModuleDefault || (Object.create ? (function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }) : function(o, v) {
        o["default"] = v;
      });
      var __importStar = exports && exports.__importStar || function(mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) {
          for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
        }
        __setModuleDefault(result, mod);
        return result;
      };
      var __exportStar = exports && exports.__exportStar || function(m, exports2) {
        for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports2, p)) __createBinding(exports2, m, p);
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.getWorstTestStepResult = exports.parseEnvelope = exports.version = exports.IdGenerator = exports.TimeConversion = void 0;
      var TimeConversion = __importStar(require_TimeConversion());
      exports.TimeConversion = TimeConversion;
      var IdGenerator = __importStar(require_IdGenerator());
      exports.IdGenerator = IdGenerator;
      var parseEnvelope_js_1 = require_parseEnvelope();
      Object.defineProperty(exports, "parseEnvelope", { enumerable: true, get: function() {
        return parseEnvelope_js_1.parseEnvelope;
      } });
      var getWorstTestStepResult_js_1 = require_getWorstTestStepResult();
      Object.defineProperty(exports, "getWorstTestStepResult", { enumerable: true, get: function() {
        return getWorstTestStepResult_js_1.getWorstTestStepResult;
      } });
      var version_js_1 = require_version();
      Object.defineProperty(exports, "version", { enumerable: true, get: function() {
        return version_js_1.version;
      } });
      __exportStar(require_messages(), exports);
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/GherkinClassicTokenMatcher.js
  var require_GherkinClassicTokenMatcher = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/GherkinClassicTokenMatcher.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        var desc = Object.getOwnPropertyDescriptor(m, k);
        if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
          desc = { enumerable: true, get: function() {
            return m[k];
          } };
        }
        Object.defineProperty(o, k2, desc);
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __setModuleDefault = exports && exports.__setModuleDefault || (Object.create ? (function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }) : function(o, v) {
        o["default"] = v;
      });
      var __importStar = exports && exports.__importStar || /* @__PURE__ */ (function() {
        var ownKeys = function(o) {
          ownKeys = Object.getOwnPropertyNames || function(o2) {
            var ar = [];
            for (var k in o2) if (Object.prototype.hasOwnProperty.call(o2, k)) ar[ar.length] = k;
            return ar;
          };
          return ownKeys(o);
        };
        return function(mod) {
          if (mod && mod.__esModule) return mod;
          var result = {};
          if (mod != null) {
            for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
          }
          __setModuleDefault(result, mod);
          return result;
        };
      })();
      var __importDefault = exports && exports.__importDefault || function(mod) {
        return mod && mod.__esModule ? mod : { "default": mod };
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      var gherkin_languages_json_1 = __importDefault(require_gherkin_languages());
      var Errors_1 = require_Errors();
      var messages = __importStar(require_src());
      var Parser_1 = require_Parser();
      var countSymbols_1 = __importDefault(require_countSymbols());
      var DIALECT_DICT = gherkin_languages_json_1.default;
      var LANGUAGE_PATTERN = /^\s*#\s*language\s*:\s*([a-zA-Z\-_]+)\s*$/;
      function addKeywordTypeMappings(h, keywords, keywordType) {
        for (const k of keywords) {
          if (!(k in h)) {
            h[k] = [];
          }
          h[k].push(keywordType);
        }
      }
      var GherkinClassicTokenMatcher2 = class {
        constructor(defaultDialectName = "en") {
          this.defaultDialectName = defaultDialectName;
          this.reset();
        }
        changeDialect(newDialectName, location) {
          const newDialect = DIALECT_DICT[newDialectName];
          if (!newDialect) {
            throw Errors_1.NoSuchLanguageException.create(newDialectName, location);
          }
          this.dialectName = newDialectName;
          this.dialect = newDialect;
          this.initializeKeywordTypes();
        }
        reset() {
          if (this.dialectName !== this.defaultDialectName) {
            this.changeDialect(this.defaultDialectName);
          }
          this.activeDocStringSeparator = null;
          this.indentToRemove = 0;
        }
        initializeKeywordTypes() {
          this.keywordTypesMap = {};
          addKeywordTypeMappings(this.keywordTypesMap, this.dialect.given, messages.StepKeywordType.CONTEXT);
          addKeywordTypeMappings(this.keywordTypesMap, this.dialect.when, messages.StepKeywordType.ACTION);
          addKeywordTypeMappings(this.keywordTypesMap, this.dialect.then, messages.StepKeywordType.OUTCOME);
          addKeywordTypeMappings(this.keywordTypesMap, [].concat(this.dialect.and).concat(this.dialect.but), messages.StepKeywordType.CONJUNCTION);
        }
        match_TagLine(token) {
          if (token.line.startsWith("@")) {
            this.setTokenMatched(token, Parser_1.TokenType.TagLine, null, null, null, null, this.getTags(token.line));
            return true;
          }
          return false;
        }
        match_FeatureLine(token) {
          return this.matchTitleLine(token, Parser_1.TokenType.FeatureLine, this.dialect.feature);
        }
        match_ScenarioLine(token) {
          return this.matchTitleLine(token, Parser_1.TokenType.ScenarioLine, this.dialect.scenario) || this.matchTitleLine(token, Parser_1.TokenType.ScenarioLine, this.dialect.scenarioOutline);
        }
        match_BackgroundLine(token) {
          return this.matchTitleLine(token, Parser_1.TokenType.BackgroundLine, this.dialect.background);
        }
        match_ExamplesLine(token) {
          return this.matchTitleLine(token, Parser_1.TokenType.ExamplesLine, this.dialect.examples);
        }
        match_RuleLine(token) {
          return this.matchTitleLine(token, Parser_1.TokenType.RuleLine, this.dialect.rule);
        }
        match_TableRow(token) {
          if (token.line.startsWith("|")) {
            this.setTokenMatched(token, Parser_1.TokenType.TableRow, null, null, null, null, token.line.getTableCells());
            return true;
          }
          return false;
        }
        match_Empty(token) {
          if (token.line.isEmpty) {
            this.setTokenMatched(token, Parser_1.TokenType.Empty, null, null, 0);
            return true;
          }
          return false;
        }
        match_Comment(token) {
          if (token.line.startsWith("#")) {
            const text = token.line.getLineText(0);
            this.setTokenMatched(token, Parser_1.TokenType.Comment, text, null, 0);
            return true;
          }
          return false;
        }
        match_Language(token) {
          const match = token.line.trimmedLineText.match(LANGUAGE_PATTERN);
          if (match) {
            const newDialectName = match[1];
            this.setTokenMatched(token, Parser_1.TokenType.Language, newDialectName);
            this.changeDialect(newDialectName, token.location);
            return true;
          }
          return false;
        }
        match_DocStringSeparator(token) {
          return this.activeDocStringSeparator == null ? (
            // open
            this._match_DocStringSeparator(token, '"""', true) || this._match_DocStringSeparator(token, "```", true)
          ) : (
            // close
            this._match_DocStringSeparator(token, this.activeDocStringSeparator, false)
          );
        }
        _match_DocStringSeparator(token, separator, isOpen) {
          if (token.line.startsWith(separator)) {
            let mediaType = null;
            if (isOpen) {
              mediaType = token.line.getRestTrimmed(separator.length);
              this.activeDocStringSeparator = separator;
              this.indentToRemove = token.line.indent;
            } else {
              this.activeDocStringSeparator = null;
              this.indentToRemove = 0;
            }
            this.setTokenMatched(token, Parser_1.TokenType.DocStringSeparator, mediaType, separator);
            return true;
          }
          return false;
        }
        match_EOF(token) {
          if (token.isEof) {
            this.setTokenMatched(token, Parser_1.TokenType.EOF);
            return true;
          }
          return false;
        }
        match_StepLine(token) {
          const keywords = [].concat(this.dialect.given).concat(this.dialect.when).concat(this.dialect.then).concat(this.dialect.and).concat(this.dialect.but);
          for (const keyword of keywords) {
            if (token.line.startsWith(keyword)) {
              const title = token.line.getRestTrimmed(keyword.length);
              const keywordTypes = this.keywordTypesMap[keyword];
              let keywordType = keywordTypes[0];
              if (keywordTypes.length > 1) {
                keywordType = messages.StepKeywordType.UNKNOWN;
              }
              this.setTokenMatched(token, Parser_1.TokenType.StepLine, title, keyword, null, keywordType);
              return true;
            }
          }
          return false;
        }
        match_Other(token) {
          const text = token.line.getLineText(this.indentToRemove);
          this.setTokenMatched(token, Parser_1.TokenType.Other, this.unescapeDocString(text), null, 0);
          return true;
        }
        getTags(line) {
          const uncommentedLine = line.trimmedLineText.split(/\s#/g, 2)[0];
          let column = line.indent + 1;
          const items = uncommentedLine.split("@");
          const tags = [];
          for (let i = 0; i < items.length; i++) {
            const item = items[i].trimRight();
            if (item.length == 0) {
              continue;
            }
            if (!item.match(/^\S+$/)) {
              throw Errors_1.ParserException.create("A tag may not contain whitespace", line.lineNumber, column);
            }
            const span = { column, text: "@" + item };
            tags.push(span);
            column += (0, countSymbols_1.default)(items[i]) + 1;
          }
          return tags;
        }
        matchTitleLine(token, tokenType, keywords) {
          for (const keyword of keywords) {
            if (token.line.startsWithTitleKeyword(keyword)) {
              const title = token.line.getRestTrimmed(keyword.length + ":".length);
              this.setTokenMatched(token, tokenType, title, keyword);
              return true;
            }
          }
          return false;
        }
        setTokenMatched(token, matchedType, text, keyword, indent, keywordType, items) {
          token.matchedType = matchedType;
          token.matchedText = text;
          token.matchedKeyword = keyword;
          token.matchedKeywordType = keywordType;
          token.matchedIndent = typeof indent === "number" ? indent : token.line == null ? 0 : token.line.indent;
          token.matchedItems = items || [];
          token.location.column = token.matchedIndent + 1;
          token.matchedGherkinDialect = this.dialectName;
        }
        unescapeDocString(text) {
          if (this.activeDocStringSeparator === '"""') {
            return text.replace('\\"\\"\\"', '"""');
          }
          if (this.activeDocStringSeparator === "```") {
            return text.replace("\\`\\`\\`", "```");
          }
          return text;
        }
      };
      exports.default = GherkinClassicTokenMatcher2;
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/pickles/compile.js
  var require_compile = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/pickles/compile.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        var desc = Object.getOwnPropertyDescriptor(m, k);
        if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
          desc = { enumerable: true, get: function() {
            return m[k];
          } };
        }
        Object.defineProperty(o, k2, desc);
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __setModuleDefault = exports && exports.__setModuleDefault || (Object.create ? (function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }) : function(o, v) {
        o["default"] = v;
      });
      var __importStar = exports && exports.__importStar || /* @__PURE__ */ (function() {
        var ownKeys = function(o) {
          ownKeys = Object.getOwnPropertyNames || function(o2) {
            var ar = [];
            for (var k in o2) if (Object.prototype.hasOwnProperty.call(o2, k)) ar[ar.length] = k;
            return ar;
          };
          return ownKeys(o);
        };
        return function(mod) {
          if (mod && mod.__esModule) return mod;
          var result = {};
          if (mod != null) {
            for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
          }
          __setModuleDefault(result, mod);
          return result;
        };
      })();
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.default = compile2;
      var messages = __importStar(require_src());
      var pickleStepTypeFromKeyword = {
        [messages.StepKeywordType.UNKNOWN]: messages.PickleStepType.UNKNOWN,
        [messages.StepKeywordType.CONTEXT]: messages.PickleStepType.CONTEXT,
        [messages.StepKeywordType.ACTION]: messages.PickleStepType.ACTION,
        [messages.StepKeywordType.OUTCOME]: messages.PickleStepType.OUTCOME,
        [messages.StepKeywordType.CONJUNCTION]: null
      };
      function compile2(gherkinDocument, uri, newId) {
        const pickles = [];
        if (gherkinDocument.feature == null) {
          return pickles;
        }
        const feature = gherkinDocument.feature;
        const language = feature.language;
        const featureTags = feature.tags;
        let featureBackgroundSteps = [];
        feature.children.forEach((stepsContainer) => {
          if (stepsContainer.background) {
            featureBackgroundSteps = [].concat(stepsContainer.background.steps);
          } else if (stepsContainer.rule) {
            compileRule(featureTags, featureBackgroundSteps, stepsContainer.rule, language, pickles, uri, newId);
          } else if (stepsContainer.scenario.examples.length === 0) {
            compileScenario(featureTags, featureBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
          } else {
            compileScenarioOutline(featureTags, featureBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
          }
        });
        return pickles;
      }
      function compileRule(featureTags, featureBackgroundSteps, rule, language, pickles, uri, newId) {
        let ruleBackgroundSteps = [].concat(featureBackgroundSteps);
        const tags = [].concat(featureTags).concat(rule.tags);
        rule.children.forEach((stepsContainer) => {
          if (stepsContainer.background) {
            ruleBackgroundSteps = ruleBackgroundSteps.concat(stepsContainer.background.steps);
          } else if (stepsContainer.scenario.examples.length === 0) {
            compileScenario(tags, ruleBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
          } else {
            compileScenarioOutline(tags, ruleBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
          }
        });
      }
      function compileScenario(inheritedTags, backgroundSteps, scenario, language, pickles, uri, newId) {
        let lastKeywordType = messages.StepKeywordType.UNKNOWN;
        const steps = [];
        if (scenario.steps.length !== 0) {
          backgroundSteps.forEach((step) => {
            lastKeywordType = step.keywordType === messages.StepKeywordType.CONJUNCTION ? lastKeywordType : step.keywordType;
            steps.push(pickleStep(step, [], null, newId, lastKeywordType));
          });
        }
        const tags = [].concat(inheritedTags).concat(scenario.tags);
        scenario.steps.forEach((step) => {
          lastKeywordType = step.keywordType === messages.StepKeywordType.CONJUNCTION ? lastKeywordType : step.keywordType;
          steps.push(pickleStep(step, [], null, newId, lastKeywordType));
        });
        const pickle = {
          id: newId(),
          uri,
          astNodeIds: [scenario.id],
          tags: pickleTags(tags),
          name: scenario.name,
          language,
          steps
        };
        pickles.push(pickle);
      }
      function compileScenarioOutline(inheritedTags, backgroundSteps, scenario, language, pickles, uri, newId) {
        scenario.examples.filter((e) => e.tableHeader).forEach((examples) => {
          const variableCells = examples.tableHeader.cells;
          examples.tableBody.forEach((valuesRow) => {
            let lastKeywordType = messages.StepKeywordType.UNKNOWN;
            const steps = [];
            if (scenario.steps.length !== 0) {
              backgroundSteps.forEach((step) => {
                lastKeywordType = step.keywordType === messages.StepKeywordType.CONJUNCTION ? lastKeywordType : step.keywordType;
                steps.push(pickleStep(step, [], null, newId, lastKeywordType));
              });
            }
            scenario.steps.forEach((scenarioOutlineStep) => {
              lastKeywordType = scenarioOutlineStep.keywordType === messages.StepKeywordType.CONJUNCTION ? lastKeywordType : scenarioOutlineStep.keywordType;
              const step = pickleStep(scenarioOutlineStep, variableCells, valuesRow, newId, lastKeywordType);
              steps.push(step);
            });
            const id = newId();
            const tags = pickleTags([].concat(inheritedTags).concat(scenario.tags).concat(examples.tags));
            pickles.push({
              id,
              uri,
              astNodeIds: [scenario.id, valuesRow.id],
              name: interpolate(scenario.name, variableCells, valuesRow.cells),
              language,
              steps,
              tags
            });
          });
        });
      }
      function createPickleArguments(step, variableCells, valueCells) {
        if (step.dataTable) {
          const argument = step.dataTable;
          const table = {
            rows: argument.rows.map((row) => {
              return {
                cells: row.cells.map((cell) => {
                  return {
                    value: interpolate(cell.value, variableCells, valueCells)
                  };
                })
              };
            })
          };
          return { dataTable: table };
        } else if (step.docString) {
          const argument = step.docString;
          const docString = {
            content: interpolate(argument.content, variableCells, valueCells)
          };
          if (argument.mediaType) {
            docString.mediaType = interpolate(argument.mediaType, variableCells, valueCells);
          }
          return { docString };
        }
      }
      function interpolate(name, variableCells, valueCells) {
        variableCells.forEach((variableCell, n) => {
          const valueCell = valueCells[n];
          const valuePattern = "<" + variableCell.value + ">";
          const escapedPattern = valuePattern.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
          const regexp = new RegExp(escapedPattern, "g");
          const replacement = valueCell.value.replace(new RegExp("\\$", "g"), "$$$$");
          name = name.replace(regexp, replacement);
        });
        return name;
      }
      function pickleStep(step, variableCells, valuesRow, newId, keywordType) {
        const astNodeIds = [step.id];
        if (valuesRow) {
          astNodeIds.push(valuesRow.id);
        }
        const valueCells = valuesRow ? valuesRow.cells : [];
        return {
          id: newId(),
          text: interpolate(step.text, variableCells, valueCells),
          type: pickleStepTypeFromKeyword[keywordType],
          argument: createPickleArguments(step, variableCells, valueCells),
          astNodeIds
        };
      }
      function pickleTags(tags) {
        return tags.map(pickleTag);
      }
      function pickleTag(tag) {
        return {
          name: tag.name,
          astNodeId: tag.id
        };
      }
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/AstNode.js
  var require_AstNode = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/AstNode.js"(exports) {
      "use strict";
      Object.defineProperty(exports, "__esModule", { value: true });
      var AstNode = class {
        constructor(ruleType) {
          this.ruleType = ruleType;
          this.subItems = /* @__PURE__ */ new Map();
        }
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        add(type, obj) {
          let items = this.subItems.get(type);
          if (items === void 0) {
            items = [];
            this.subItems.set(type, items);
          }
          items.push(obj);
        }
        getSingle(ruleType) {
          return (this.subItems.get(ruleType) || [])[0];
        }
        getItems(ruleType) {
          return this.subItems.get(ruleType) || [];
        }
        getToken(tokenType) {
          return (this.subItems.get(tokenType) || [])[0];
        }
        getTokens(tokenType) {
          return this.subItems.get(tokenType) || [];
        }
      };
      exports.default = AstNode;
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/AstBuilder.js
  var require_AstBuilder = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/AstBuilder.js"(exports) {
      "use strict";
      var __importDefault = exports && exports.__importDefault || function(mod) {
        return mod && mod.__esModule ? mod : { "default": mod };
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      var AstNode_1 = __importDefault(require_AstNode());
      var Parser_1 = require_Parser();
      var Errors_1 = require_Errors();
      var AstBuilder2 = class {
        constructor(newId) {
          this.newId = newId;
          if (!newId) {
            throw new Error("No newId");
          }
          this.reset();
        }
        reset() {
          this.stack = [new AstNode_1.default(Parser_1.RuleType.None)];
          this.comments = [];
        }
        startRule(ruleType) {
          this.stack.push(new AstNode_1.default(ruleType));
        }
        endRule() {
          const node = this.stack.pop();
          const transformedNode = this.transformNode(node);
          this.currentNode().add(node.ruleType, transformedNode);
        }
        build(token) {
          if (token.matchedType === Parser_1.TokenType.Comment) {
            this.comments.push({
              location: this.getLocation(token),
              text: token.matchedText
            });
          } else {
            this.currentNode().add(token.matchedType, token);
          }
        }
        getResult() {
          return this.currentNode().getSingle(Parser_1.RuleType.GherkinDocument);
        }
        currentNode() {
          return this.stack[this.stack.length - 1];
        }
        getLocation(token, column) {
          return !column ? token.location : { line: token.location.line, column };
        }
        getTags(node) {
          const tags = [];
          const tagsNode = node.getSingle(Parser_1.RuleType.Tags);
          if (!tagsNode) {
            return tags;
          }
          const tokens = tagsNode.getTokens(Parser_1.TokenType.TagLine);
          for (const token of tokens) {
            for (const tagItem of token.matchedItems) {
              tags.push({
                location: this.getLocation(token, tagItem.column),
                name: tagItem.text,
                id: this.newId()
              });
            }
          }
          return tags;
        }
        getCells(tableRowToken) {
          return tableRowToken.matchedItems.map((cellItem) => ({
            location: this.getLocation(tableRowToken, cellItem.column),
            value: cellItem.text
          }));
        }
        getDescription(node) {
          return node.getSingle(Parser_1.RuleType.Description) || "";
        }
        getSteps(node) {
          return node.getItems(Parser_1.RuleType.Step);
        }
        getTableRows(node) {
          const rows = node.getTokens(Parser_1.TokenType.TableRow).map((token) => ({
            id: this.newId(),
            location: this.getLocation(token),
            cells: this.getCells(token)
          }));
          this.ensureCellCount(rows);
          return rows.length === 0 ? [] : rows;
        }
        ensureCellCount(rows) {
          if (rows.length === 0) {
            return;
          }
          const cellCount = rows[0].cells.length;
          rows.forEach((row) => {
            if (row.cells.length !== cellCount) {
              throw Errors_1.AstBuilderException.create("inconsistent cell count within the table", row.location);
            }
          });
        }
        transformNode(node) {
          switch (node.ruleType) {
            case Parser_1.RuleType.Step: {
              const stepLine = node.getToken(Parser_1.TokenType.StepLine);
              const dataTable = node.getSingle(Parser_1.RuleType.DataTable);
              const docString = node.getSingle(Parser_1.RuleType.DocString);
              const location = this.getLocation(stepLine);
              const step = {
                id: this.newId(),
                location,
                keyword: stepLine.matchedKeyword,
                keywordType: stepLine.matchedKeywordType,
                text: stepLine.matchedText,
                dataTable,
                docString
              };
              return step;
            }
            case Parser_1.RuleType.DocString: {
              const separatorToken = node.getTokens(Parser_1.TokenType.DocStringSeparator)[0];
              const mediaType = separatorToken.matchedText.length > 0 ? separatorToken.matchedText : void 0;
              const lineTokens = node.getTokens(Parser_1.TokenType.Other);
              const content = lineTokens.map((t) => t.matchedText).join("\n");
              const result = {
                location: this.getLocation(separatorToken),
                content,
                delimiter: separatorToken.matchedKeyword
              };
              if (mediaType) {
                result.mediaType = mediaType;
              }
              return result;
            }
            case Parser_1.RuleType.DataTable: {
              const rows = this.getTableRows(node);
              const dataTable = {
                location: rows[0].location,
                rows
              };
              return dataTable;
            }
            case Parser_1.RuleType.Background: {
              const backgroundLine = node.getToken(Parser_1.TokenType.BackgroundLine);
              const description = this.getDescription(node);
              const steps = this.getSteps(node);
              const background = {
                id: this.newId(),
                location: this.getLocation(backgroundLine),
                keyword: backgroundLine.matchedKeyword,
                name: backgroundLine.matchedText,
                description,
                steps
              };
              return background;
            }
            case Parser_1.RuleType.ScenarioDefinition: {
              const tags = this.getTags(node);
              const scenarioNode = node.getSingle(Parser_1.RuleType.Scenario);
              const scenarioLine = scenarioNode.getToken(Parser_1.TokenType.ScenarioLine);
              const description = this.getDescription(scenarioNode);
              const steps = this.getSteps(scenarioNode);
              const examples = scenarioNode.getItems(Parser_1.RuleType.ExamplesDefinition);
              const scenario = {
                id: this.newId(),
                tags,
                location: this.getLocation(scenarioLine),
                keyword: scenarioLine.matchedKeyword,
                name: scenarioLine.matchedText,
                description,
                steps,
                examples
              };
              return scenario;
            }
            case Parser_1.RuleType.ExamplesDefinition: {
              const tags = this.getTags(node);
              const examplesNode = node.getSingle(Parser_1.RuleType.Examples);
              const examplesLine = examplesNode.getToken(Parser_1.TokenType.ExamplesLine);
              const description = this.getDescription(examplesNode);
              const examplesTable = examplesNode.getSingle(Parser_1.RuleType.ExamplesTable);
              const examples = {
                id: this.newId(),
                tags,
                location: this.getLocation(examplesLine),
                keyword: examplesLine.matchedKeyword,
                name: examplesLine.matchedText,
                description,
                tableHeader: examplesTable ? examplesTable[0] : void 0,
                tableBody: examplesTable ? examplesTable.slice(1) : []
              };
              return examples;
            }
            case Parser_1.RuleType.ExamplesTable: {
              return this.getTableRows(node);
            }
            case Parser_1.RuleType.Description: {
              let lineTokens = node.getTokens(Parser_1.TokenType.Other);
              let end = lineTokens.length;
              while (end > 0 && lineTokens[end - 1].line.trimmedLineText === "") {
                end--;
              }
              lineTokens = lineTokens.slice(0, end);
              return lineTokens.map((token) => token.matchedText).join("\n");
            }
            case Parser_1.RuleType.Feature: {
              const header = node.getSingle(Parser_1.RuleType.FeatureHeader);
              if (!header) {
                return null;
              }
              const tags = this.getTags(header);
              const featureLine = header.getToken(Parser_1.TokenType.FeatureLine);
              if (!featureLine) {
                return null;
              }
              const children = [];
              const background = node.getSingle(Parser_1.RuleType.Background);
              if (background) {
                children.push({
                  background
                });
              }
              for (const scenario of node.getItems(Parser_1.RuleType.ScenarioDefinition)) {
                children.push({
                  scenario
                });
              }
              for (const rule of node.getItems(Parser_1.RuleType.Rule)) {
                children.push({
                  rule
                });
              }
              const description = this.getDescription(header);
              const language = featureLine.matchedGherkinDialect;
              const feature = {
                tags,
                location: this.getLocation(featureLine),
                language,
                keyword: featureLine.matchedKeyword,
                name: featureLine.matchedText,
                description,
                children
              };
              return feature;
            }
            case Parser_1.RuleType.Rule: {
              const header = node.getSingle(Parser_1.RuleType.RuleHeader);
              if (!header) {
                return null;
              }
              const ruleLine = header.getToken(Parser_1.TokenType.RuleLine);
              if (!ruleLine) {
                return null;
              }
              const tags = this.getTags(header);
              const children = [];
              const background = node.getSingle(Parser_1.RuleType.Background);
              if (background) {
                children.push({
                  background
                });
              }
              for (const scenario of node.getItems(Parser_1.RuleType.ScenarioDefinition)) {
                children.push({
                  scenario
                });
              }
              const description = this.getDescription(header);
              const rule = {
                id: this.newId(),
                location: this.getLocation(ruleLine),
                keyword: ruleLine.matchedKeyword,
                name: ruleLine.matchedText,
                description,
                children,
                tags
              };
              return rule;
            }
            case Parser_1.RuleType.GherkinDocument: {
              const feature = node.getSingle(Parser_1.RuleType.Feature);
              const gherkinDocument = {
                feature,
                comments: this.comments
              };
              return gherkinDocument;
            }
            default:
              return node;
          }
        }
      };
      exports.default = AstBuilder2;
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/makeSourceEnvelope.js
  var require_makeSourceEnvelope = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/makeSourceEnvelope.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        var desc = Object.getOwnPropertyDescriptor(m, k);
        if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
          desc = { enumerable: true, get: function() {
            return m[k];
          } };
        }
        Object.defineProperty(o, k2, desc);
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __setModuleDefault = exports && exports.__setModuleDefault || (Object.create ? (function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }) : function(o, v) {
        o["default"] = v;
      });
      var __importStar = exports && exports.__importStar || /* @__PURE__ */ (function() {
        var ownKeys = function(o) {
          ownKeys = Object.getOwnPropertyNames || function(o2) {
            var ar = [];
            for (var k in o2) if (Object.prototype.hasOwnProperty.call(o2, k)) ar[ar.length] = k;
            return ar;
          };
          return ownKeys(o);
        };
        return function(mod) {
          if (mod && mod.__esModule) return mod;
          var result = {};
          if (mod != null) {
            for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
          }
          __setModuleDefault(result, mod);
          return result;
        };
      })();
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.default = makeSourceEnvelope;
      var messages = __importStar(require_src());
      function makeSourceEnvelope(data, uri) {
        let mediaType;
        if (uri.endsWith(".feature")) {
          mediaType = messages.SourceMediaType.TEXT_X_CUCUMBER_GHERKIN_PLAIN;
        } else if (uri.endsWith(".md")) {
          mediaType = messages.SourceMediaType.TEXT_X_CUCUMBER_GHERKIN_MARKDOWN;
        }
        if (!mediaType)
          throw new Error(`The uri (${uri}) must end with .feature or .md`);
        return {
          source: {
            data,
            uri,
            mediaType
          }
        };
      }
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/GherkinInMarkdownTokenMatcher.js
  var require_GherkinInMarkdownTokenMatcher = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/GherkinInMarkdownTokenMatcher.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        var desc = Object.getOwnPropertyDescriptor(m, k);
        if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
          desc = { enumerable: true, get: function() {
            return m[k];
          } };
        }
        Object.defineProperty(o, k2, desc);
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __setModuleDefault = exports && exports.__setModuleDefault || (Object.create ? (function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }) : function(o, v) {
        o["default"] = v;
      });
      var __importStar = exports && exports.__importStar || /* @__PURE__ */ (function() {
        var ownKeys = function(o) {
          ownKeys = Object.getOwnPropertyNames || function(o2) {
            var ar = [];
            for (var k in o2) if (Object.prototype.hasOwnProperty.call(o2, k)) ar[ar.length] = k;
            return ar;
          };
          return ownKeys(o);
        };
        return function(mod) {
          if (mod && mod.__esModule) return mod;
          var result = {};
          if (mod != null) {
            for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
          }
          __setModuleDefault(result, mod);
          return result;
        };
      })();
      var __importDefault = exports && exports.__importDefault || function(mod) {
        return mod && mod.__esModule ? mod : { "default": mod };
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      var Parser_1 = require_Parser();
      var gherkin_languages_json_1 = __importDefault(require_gherkin_languages());
      var messages = __importStar(require_src());
      var Errors_1 = require_Errors();
      var DIALECT_DICT = gherkin_languages_json_1.default;
      var DEFAULT_DOC_STRING_SEPARATOR = /^(```[`]*)(.*)/;
      function addKeywordTypeMappings(h, keywords, keywordType) {
        for (const k of keywords) {
          if (!(k in h)) {
            h[k] = [];
          }
          h[k].push(keywordType);
        }
      }
      var GherkinInMarkdownTokenMatcher = class {
        constructor(defaultDialectName = "en") {
          this.defaultDialectName = defaultDialectName;
          this.dialect = DIALECT_DICT[defaultDialectName];
          this.nonStarStepKeywords = [].concat(this.dialect.given).concat(this.dialect.when).concat(this.dialect.then).concat(this.dialect.and).concat(this.dialect.but).filter((value, index, self2) => value !== "* " && self2.indexOf(value) === index);
          this.initializeKeywordTypes();
          this.stepRegexp = new RegExp(`${KeywordPrefix.BULLET}(${this.nonStarStepKeywords.map(escapeRegExp).join("|")})`);
          const headerKeywords = [].concat(this.dialect.feature).concat(this.dialect.background).concat(this.dialect.rule).concat(this.dialect.scenarioOutline).concat(this.dialect.scenario).concat(this.dialect.examples).filter((value, index, self2) => self2.indexOf(value) === index);
          this.headerRegexp = new RegExp(`${KeywordPrefix.HEADER}(${headerKeywords.map(escapeRegExp).join("|")})`);
          this.reset();
        }
        changeDialect(newDialectName, location) {
          const newDialect = DIALECT_DICT[newDialectName];
          if (!newDialect) {
            throw Errors_1.NoSuchLanguageException.create(newDialectName, location);
          }
          this.dialectName = newDialectName;
          this.dialect = newDialect;
          this.initializeKeywordTypes();
        }
        initializeKeywordTypes() {
          this.keywordTypesMap = {};
          addKeywordTypeMappings(this.keywordTypesMap, this.dialect.given, messages.StepKeywordType.CONTEXT);
          addKeywordTypeMappings(this.keywordTypesMap, this.dialect.when, messages.StepKeywordType.ACTION);
          addKeywordTypeMappings(this.keywordTypesMap, this.dialect.then, messages.StepKeywordType.OUTCOME);
          addKeywordTypeMappings(this.keywordTypesMap, [].concat(this.dialect.and).concat(this.dialect.but), messages.StepKeywordType.CONJUNCTION);
        }
        // We've made a deliberate choice not to support `# language: [ISO 639-1]` headers or similar
        // in Markdown. Users should specify a language globally. This can be done in
        // cucumber-js using the --language [ISO 639-1] option.
        match_Language(token) {
          if (!token)
            throw new Error("no token");
          return false;
        }
        match_Empty(token) {
          let result = false;
          if (token.line.isEmpty) {
            result = true;
          }
          if (!this.match_TagLine(token) && !this.match_FeatureLine(token) && !this.match_ScenarioLine(token) && !this.match_BackgroundLine(token) && !this.match_ExamplesLine(token) && !this.match_RuleLine(token) && !this.match_TableRow(token) && !this.match_Comment(token) && !this.match_Language(token) && !this.match_DocStringSeparator(token) && !this.match_EOF(token) && !this.match_StepLine(token)) {
            result = true;
          }
          if (result) {
            token.matchedType = Parser_1.TokenType.Empty;
          }
          return this.setTokenMatched(token, null, result);
        }
        match_Other(token) {
          const text = token.line.getLineText(this.indentToRemove);
          token.matchedType = Parser_1.TokenType.Other;
          token.matchedText = text;
          token.matchedIndent = 0;
          return this.setTokenMatched(token, null, true);
        }
        match_Comment(token) {
          let result = false;
          if (token.line.startsWith("|")) {
            const tableCells = token.line.getTableCells();
            if (this.isGfmTableSeparator(tableCells))
              result = true;
          }
          return this.setTokenMatched(token, null, result);
        }
        match_DocStringSeparator(token) {
          const match = token.line.trimmedLineText.match(this.activeDocStringSeparator);
          const [, newSeparator, mediaType] = match || [];
          let result = false;
          if (newSeparator) {
            if (this.activeDocStringSeparator === DEFAULT_DOC_STRING_SEPARATOR) {
              this.activeDocStringSeparator = new RegExp(`^(${newSeparator})$`);
              this.indentToRemove = token.line.indent;
            } else {
              this.activeDocStringSeparator = DEFAULT_DOC_STRING_SEPARATOR;
            }
            token.matchedKeyword = newSeparator;
            token.matchedType = Parser_1.TokenType.DocStringSeparator;
            token.matchedText = mediaType || "";
            result = true;
          }
          return this.setTokenMatched(token, null, result);
        }
        match_EOF(token) {
          let result = false;
          if (token.isEof) {
            token.matchedType = Parser_1.TokenType.EOF;
            result = true;
          }
          return this.setTokenMatched(token, null, result);
        }
        match_FeatureLine(token) {
          if (this.matchedFeatureLine) {
            return this.setTokenMatched(token, null, false);
          }
          let result = this.matchTitleLine(KeywordPrefix.HEADER, this.dialect.feature, ":", token, Parser_1.TokenType.FeatureLine);
          if (!result) {
            token.matchedType = Parser_1.TokenType.FeatureLine;
            token.matchedText = token.line.trimmedLineText;
            result = this.setTokenMatched(token, null, true);
          }
          this.matchedFeatureLine = result;
          return result;
        }
        match_BackgroundLine(token) {
          return this.matchTitleLine(KeywordPrefix.HEADER, this.dialect.background, ":", token, Parser_1.TokenType.BackgroundLine);
        }
        match_RuleLine(token) {
          return this.matchTitleLine(KeywordPrefix.HEADER, this.dialect.rule, ":", token, Parser_1.TokenType.RuleLine);
        }
        match_ScenarioLine(token) {
          return this.matchTitleLine(KeywordPrefix.HEADER, this.dialect.scenario, ":", token, Parser_1.TokenType.ScenarioLine) || this.matchTitleLine(KeywordPrefix.HEADER, this.dialect.scenarioOutline, ":", token, Parser_1.TokenType.ScenarioLine);
        }
        match_ExamplesLine(token) {
          return this.matchTitleLine(KeywordPrefix.HEADER, this.dialect.examples, ":", token, Parser_1.TokenType.ExamplesLine);
        }
        match_StepLine(token) {
          return this.matchTitleLine(KeywordPrefix.BULLET, this.nonStarStepKeywords, "", token, Parser_1.TokenType.StepLine);
        }
        matchTitleLine(prefix, keywords, keywordSuffix, token, matchedType) {
          const regexp = new RegExp(`${prefix}(${keywords.map(escapeRegExp).join("|")})${keywordSuffix}(.*)`);
          const match = token.line.match(regexp);
          let indent = token.line.indent;
          let result = false;
          if (match) {
            token.matchedType = matchedType;
            token.matchedKeyword = match[2];
            if (match[2] in this.keywordTypesMap) {
              if (this.keywordTypesMap[match[2]].length > 1) {
                token.matchedKeywordType = messages.StepKeywordType.UNKNOWN;
              } else {
                token.matchedKeywordType = this.keywordTypesMap[match[2]][0];
              }
            }
            token.matchedText = match[3].trim();
            indent += match[1].length;
            result = true;
          }
          return this.setTokenMatched(token, indent, result);
        }
        setTokenMatched(token, indent, matched) {
          token.matchedGherkinDialect = this.dialectName;
          token.matchedIndent = indent !== null ? indent : token.line == null ? 0 : token.line.indent;
          token.location.column = token.matchedIndent + 1;
          return matched;
        }
        match_TableRow(token) {
          if (token.line.lineText.match(/^\s\s\s?\s?\s?\|/)) {
            const tableCells = token.line.getTableCells();
            if (this.isGfmTableSeparator(tableCells))
              return false;
            token.matchedKeyword = "|";
            token.matchedType = Parser_1.TokenType.TableRow;
            token.matchedItems = tableCells;
            return true;
          }
          return false;
        }
        isGfmTableSeparator(tableCells) {
          const separatorValues = tableCells.map((item) => item.text).filter((value) => value.match(/^:?-+:?$/));
          return separatorValues.length > 0;
        }
        match_TagLine(token) {
          const tags = [];
          let m;
          const re = /`(@[^`]+)`/g;
          do {
            m = re.exec(token.line.trimmedLineText);
            if (m) {
              tags.push({
                column: token.line.indent + m.index + 2,
                text: m[1]
              });
            }
          } while (m);
          if (tags.length === 0)
            return false;
          token.matchedType = Parser_1.TokenType.TagLine;
          token.matchedItems = tags;
          return true;
        }
        reset() {
          if (this.dialectName !== this.defaultDialectName) {
            this.changeDialect(this.defaultDialectName);
          }
          this.activeDocStringSeparator = DEFAULT_DOC_STRING_SEPARATOR;
        }
      };
      exports.default = GherkinInMarkdownTokenMatcher;
      var KeywordPrefix;
      (function(KeywordPrefix2) {
        KeywordPrefix2["BULLET"] = "^(\\s*[*+-]\\s*)";
        KeywordPrefix2["HEADER"] = "^(#{1,6}\\s)";
      })(KeywordPrefix || (KeywordPrefix = {}));
      function escapeRegExp(text) {
        return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
      }
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/generateMessages.js
  var require_generateMessages = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/generateMessages.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        var desc = Object.getOwnPropertyDescriptor(m, k);
        if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
          desc = { enumerable: true, get: function() {
            return m[k];
          } };
        }
        Object.defineProperty(o, k2, desc);
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __setModuleDefault = exports && exports.__setModuleDefault || (Object.create ? (function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }) : function(o, v) {
        o["default"] = v;
      });
      var __importStar = exports && exports.__importStar || /* @__PURE__ */ (function() {
        var ownKeys = function(o) {
          ownKeys = Object.getOwnPropertyNames || function(o2) {
            var ar = [];
            for (var k in o2) if (Object.prototype.hasOwnProperty.call(o2, k)) ar[ar.length] = k;
            return ar;
          };
          return ownKeys(o);
        };
        return function(mod) {
          if (mod && mod.__esModule) return mod;
          var result = {};
          if (mod != null) {
            for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
          }
          __setModuleDefault(result, mod);
          return result;
        };
      })();
      var __importDefault = exports && exports.__importDefault || function(mod) {
        return mod && mod.__esModule ? mod : { "default": mod };
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.default = generateMessages;
      var Parser_1 = __importDefault(require_Parser());
      var GherkinClassicTokenMatcher_1 = __importDefault(require_GherkinClassicTokenMatcher());
      var messages = __importStar(require_src());
      var compile_1 = __importDefault(require_compile());
      var AstBuilder_1 = __importDefault(require_AstBuilder());
      var makeSourceEnvelope_1 = __importDefault(require_makeSourceEnvelope());
      var GherkinInMarkdownTokenMatcher_1 = __importDefault(require_GherkinInMarkdownTokenMatcher());
      function generateMessages(data, uri, mediaType, options) {
        let tokenMatcher;
        switch (mediaType) {
          case messages.SourceMediaType.TEXT_X_CUCUMBER_GHERKIN_PLAIN:
            tokenMatcher = new GherkinClassicTokenMatcher_1.default(options.defaultDialect);
            break;
          case messages.SourceMediaType.TEXT_X_CUCUMBER_GHERKIN_MARKDOWN:
            tokenMatcher = new GherkinInMarkdownTokenMatcher_1.default(options.defaultDialect);
            break;
          default:
            throw new Error(`Unsupported media type: ${mediaType}`);
        }
        const result = [];
        try {
          if (options.includeSource) {
            result.push((0, makeSourceEnvelope_1.default)(data, uri));
          }
          if (!options.includeGherkinDocument && !options.includePickles) {
            return result;
          }
          const parser = new Parser_1.default(new AstBuilder_1.default(options.newId), tokenMatcher);
          parser.stopAtFirstError = false;
          const gherkinDocument = parser.parse(data);
          if (options.includeGherkinDocument) {
            result.push({
              gherkinDocument: { ...gherkinDocument, uri }
            });
          }
          if (options.includePickles) {
            const pickles = (0, compile_1.default)(gherkinDocument, uri, options.newId);
            for (const pickle of pickles) {
              result.push({
                pickle
              });
            }
          }
        } catch (err) {
          const errors = err.errors || [err];
          for (const error of errors) {
            if (!error.location) {
              throw error;
            }
            result.push({
              parseError: {
                source: {
                  uri,
                  location: {
                    line: error.location.line,
                    column: error.location.column
                  }
                },
                message: error.message
              }
            });
          }
        }
        return result;
      }
    }
  });

  // node_modules/@cucumber/gherkin/dist/src/index.js
  var require_src2 = __commonJS({
    "node_modules/@cucumber/gherkin/dist/src/index.js"(exports) {
      "use strict";
      var __createBinding = exports && exports.__createBinding || (Object.create ? (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        var desc = Object.getOwnPropertyDescriptor(m, k);
        if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
          desc = { enumerable: true, get: function() {
            return m[k];
          } };
        }
        Object.defineProperty(o, k2, desc);
      }) : (function(o, m, k, k2) {
        if (k2 === void 0) k2 = k;
        o[k2] = m[k];
      }));
      var __setModuleDefault = exports && exports.__setModuleDefault || (Object.create ? (function(o, v) {
        Object.defineProperty(o, "default", { enumerable: true, value: v });
      }) : function(o, v) {
        o["default"] = v;
      });
      var __importStar = exports && exports.__importStar || /* @__PURE__ */ (function() {
        var ownKeys = function(o) {
          ownKeys = Object.getOwnPropertyNames || function(o2) {
            var ar = [];
            for (var k in o2) if (Object.prototype.hasOwnProperty.call(o2, k)) ar[ar.length] = k;
            return ar;
          };
          return ownKeys(o);
        };
        return function(mod) {
          if (mod && mod.__esModule) return mod;
          var result = {};
          if (mod != null) {
            for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
          }
          __setModuleDefault(result, mod);
          return result;
        };
      })();
      var __importDefault = exports && exports.__importDefault || function(mod) {
        return mod && mod.__esModule ? mod : { "default": mod };
      };
      Object.defineProperty(exports, "__esModule", { value: true });
      exports.compile = exports.GherkinInMarkdownTokenMatcher = exports.GherkinClassicTokenMatcher = exports.Errors = exports.TokenScanner = exports.AstBuilder = exports.Parser = exports.dialects = exports.makeSourceEnvelope = exports.generateMessages = void 0;
      var generateMessages_1 = __importDefault(require_generateMessages());
      exports.generateMessages = generateMessages_1.default;
      var makeSourceEnvelope_1 = __importDefault(require_makeSourceEnvelope());
      exports.makeSourceEnvelope = makeSourceEnvelope_1.default;
      var Parser_1 = __importDefault(require_Parser());
      exports.Parser = Parser_1.default;
      var AstBuilder_1 = __importDefault(require_AstBuilder());
      exports.AstBuilder = AstBuilder_1.default;
      var TokenScanner_1 = __importDefault(require_TokenScanner());
      exports.TokenScanner = TokenScanner_1.default;
      var Errors = __importStar(require_Errors());
      exports.Errors = Errors;
      var compile_1 = __importDefault(require_compile());
      exports.compile = compile_1.default;
      var gherkin_languages_json_1 = __importDefault(require_gherkin_languages());
      var GherkinClassicTokenMatcher_1 = __importDefault(require_GherkinClassicTokenMatcher());
      exports.GherkinClassicTokenMatcher = GherkinClassicTokenMatcher_1.default;
      var GherkinInMarkdownTokenMatcher_1 = __importDefault(require_GherkinInMarkdownTokenMatcher());
      exports.GherkinInMarkdownTokenMatcher = GherkinInMarkdownTokenMatcher_1.default;
      var dialects = gherkin_languages_json_1.default;
      exports.dialects = dialects;
    }
  });

  // node_modules/regexp-match-indices/config.js
  var require_config = __commonJS({
    "node_modules/regexp-match-indices/config.js"(exports, module) {
      "use strict";
      var config = {
        mode: "lazy"
      };
      module.exports = config;
    }
  });

  // node_modules/regexp-match-indices/native.js
  var require_native = __commonJS({
    "node_modules/regexp-match-indices/native.js"(exports, module) {
      "use strict";
      var nativeExec = RegExp.prototype.exec;
      module.exports = nativeExec;
    }
  });

  // node_modules/regexp-tree/dist/compat-transpiler/transforms/compat-dotall-s-transform.js
  var require_compat_dotall_s_transform = __commonJS({
    "node_modules/regexp-tree/dist/compat-transpiler/transforms/compat-dotall-s-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        // Whether `u` flag present. In which case we transform to
        // \u{10FFFF} instead of \uFFFF.
        _hasUFlag: false,
        // Only run this plugin if we have `s` flag.
        shouldRun: function shouldRun(ast) {
          var shouldRun2 = ast.flags.includes("s");
          if (!shouldRun2) {
            return false;
          }
          ast.flags = ast.flags.replace("s", "");
          this._hasUFlag = ast.flags.includes("u");
          return true;
        },
        Char: function Char(path) {
          var node = path.node;
          if (node.kind !== "meta" || node.value !== ".") {
            return;
          }
          var toValue = "\\uFFFF";
          var toSymbol = "\uFFFF";
          if (this._hasUFlag) {
            toValue = "\\u{10FFFF}";
            toSymbol = "\u{10FFFF}";
          }
          path.replace({
            type: "CharacterClass",
            expressions: [{
              type: "ClassRange",
              from: {
                type: "Char",
                value: "\\0",
                kind: "decimal",
                symbol: "\0"
              },
              to: {
                type: "Char",
                value: toValue,
                kind: "unicode",
                symbol: toSymbol
              }
            }]
          });
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/compat-transpiler/transforms/compat-named-capturing-groups-transform.js
  var require_compat_named_capturing_groups_transform = __commonJS({
    "node_modules/regexp-tree/dist/compat-transpiler/transforms/compat-named-capturing-groups-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        // To track the names of the groups, and return them
        // in the transform result state.
        //
        // A map from name to number: {foo: 2, bar: 4}
        _groupNames: {},
        /**
         * Initialises the trasnform.
         */
        init: function init() {
          this._groupNames = {};
        },
        /**
         * Returns extra state, which eventually is returned to
         */
        getExtra: function getExtra() {
          return this._groupNames;
        },
        Group: function Group3(path) {
          var node = path.node;
          if (!node.name) {
            return;
          }
          this._groupNames[node.name] = node.number;
          delete node.name;
          delete node.nameRaw;
        },
        Backreference: function Backreference(path) {
          var node = path.node;
          if (node.kind !== "name") {
            return;
          }
          node.kind = "number";
          node.reference = node.number;
          delete node.referenceRaw;
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/compat-transpiler/transforms/compat-x-flag-transform.js
  var require_compat_x_flag_transform = __commonJS({
    "node_modules/regexp-tree/dist/compat-transpiler/transforms/compat-x-flag-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        RegExp: function RegExp2(_ref) {
          var node = _ref.node;
          if (node.flags.includes("x")) {
            node.flags = node.flags.replace("x", "");
          }
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/compat-transpiler/transforms/index.js
  var require_transforms = __commonJS({
    "node_modules/regexp-tree/dist/compat-transpiler/transforms/index.js"(exports, module) {
      "use strict";
      module.exports = {
        // "dotAll" `s` flag
        dotAll: require_compat_dotall_s_transform(),
        // Named capturing groups.
        namedCapturingGroups: require_compat_named_capturing_groups_transform(),
        // `x` flag
        xFlag: require_compat_x_flag_transform()
      };
    }
  });

  // node_modules/regexp-tree/dist/generator/index.js
  var require_generator = __commonJS({
    "node_modules/regexp-tree/dist/generator/index.js"(exports, module) {
      "use strict";
      function gen(node) {
        return node ? generator[node.type](node) : "";
      }
      var generator = {
        RegExp: function RegExp2(node) {
          return "/" + gen(node.body) + "/" + node.flags;
        },
        Alternative: function Alternative(node) {
          return (node.expressions || []).map(gen).join("");
        },
        Disjunction: function Disjunction(node) {
          return gen(node.left) + "|" + gen(node.right);
        },
        Group: function Group3(node) {
          var expression = gen(node.expression);
          if (node.capturing) {
            if (node.name) {
              return "(?<" + (node.nameRaw || node.name) + ">" + expression + ")";
            }
            return "(" + expression + ")";
          }
          return "(?:" + expression + ")";
        },
        Backreference: function Backreference(node) {
          switch (node.kind) {
            case "number":
              return "\\" + node.reference;
            case "name":
              return "\\k<" + (node.referenceRaw || node.reference) + ">";
            default:
              throw new TypeError("Unknown Backreference kind: " + node.kind);
          }
        },
        Assertion: function Assertion(node) {
          switch (node.kind) {
            case "^":
            case "$":
            case "\\b":
            case "\\B":
              return node.kind;
            case "Lookahead": {
              var assertion = gen(node.assertion);
              if (node.negative) {
                return "(?!" + assertion + ")";
              }
              return "(?=" + assertion + ")";
            }
            case "Lookbehind": {
              var _assertion = gen(node.assertion);
              if (node.negative) {
                return "(?<!" + _assertion + ")";
              }
              return "(?<=" + _assertion + ")";
            }
            default:
              throw new TypeError("Unknown Assertion kind: " + node.kind);
          }
        },
        CharacterClass: function CharacterClass(node) {
          var expressions = node.expressions.map(gen).join("");
          if (node.negative) {
            return "[^" + expressions + "]";
          }
          return "[" + expressions + "]";
        },
        ClassRange: function ClassRange(node) {
          return gen(node.from) + "-" + gen(node.to);
        },
        Repetition: function Repetition(node) {
          return "" + gen(node.expression) + gen(node.quantifier);
        },
        Quantifier: function Quantifier(node) {
          var quantifier = void 0;
          var greedy = node.greedy ? "" : "?";
          switch (node.kind) {
            case "+":
            case "?":
            case "*":
              quantifier = node.kind;
              break;
            case "Range":
              if (node.from === node.to) {
                quantifier = "{" + node.from + "}";
              } else if (!node.to) {
                quantifier = "{" + node.from + ",}";
              } else {
                quantifier = "{" + node.from + "," + node.to + "}";
              }
              break;
            default:
              throw new TypeError("Unknown Quantifier kind: " + node.kind);
          }
          return "" + quantifier + greedy;
        },
        Char: function Char(node) {
          var value = node.value;
          switch (node.kind) {
            case "simple": {
              if (node.escaped) {
                return "\\" + value;
              }
              return value;
            }
            case "hex":
            case "unicode":
            case "oct":
            case "decimal":
            case "control":
            case "meta":
              return value;
            default:
              throw new TypeError("Unknown Char kind: " + node.kind);
          }
        },
        UnicodeProperty: function UnicodeProperty(node) {
          var escapeChar = node.negative ? "P" : "p";
          var namePart = void 0;
          if (!node.shorthand && !node.binary) {
            namePart = node.name + "=";
          } else {
            namePart = "";
          }
          return "\\" + escapeChar + "{" + namePart + node.value + "}";
        }
      };
      module.exports = {
        /**
         * Generates a regexp string from an AST.
         *
         * @param Object ast - an AST node
         */
        generate: gen
      };
    }
  });

  // node_modules/regexp-tree/dist/parser/unicode/parser-unicode-properties.js
  var require_parser_unicode_properties = __commonJS({
    "node_modules/regexp-tree/dist/parser/unicode/parser-unicode-properties.js"(exports, module) {
      "use strict";
      var NON_BINARY_PROP_NAMES_TO_ALIASES = {
        General_Category: "gc",
        Script: "sc",
        Script_Extensions: "scx"
      };
      var NON_BINARY_ALIASES_TO_PROP_NAMES = inverseMap(NON_BINARY_PROP_NAMES_TO_ALIASES);
      var BINARY_PROP_NAMES_TO_ALIASES = {
        ASCII: "ASCII",
        ASCII_Hex_Digit: "AHex",
        Alphabetic: "Alpha",
        Any: "Any",
        Assigned: "Assigned",
        Bidi_Control: "Bidi_C",
        Bidi_Mirrored: "Bidi_M",
        Case_Ignorable: "CI",
        Cased: "Cased",
        Changes_When_Casefolded: "CWCF",
        Changes_When_Casemapped: "CWCM",
        Changes_When_Lowercased: "CWL",
        Changes_When_NFKC_Casefolded: "CWKCF",
        Changes_When_Titlecased: "CWT",
        Changes_When_Uppercased: "CWU",
        Dash: "Dash",
        Default_Ignorable_Code_Point: "DI",
        Deprecated: "Dep",
        Diacritic: "Dia",
        Emoji: "Emoji",
        Emoji_Component: "Emoji_Component",
        Emoji_Modifier: "Emoji_Modifier",
        Emoji_Modifier_Base: "Emoji_Modifier_Base",
        Emoji_Presentation: "Emoji_Presentation",
        Extended_Pictographic: "Extended_Pictographic",
        Extender: "Ext",
        Grapheme_Base: "Gr_Base",
        Grapheme_Extend: "Gr_Ext",
        Hex_Digit: "Hex",
        IDS_Binary_Operator: "IDSB",
        IDS_Trinary_Operator: "IDST",
        ID_Continue: "IDC",
        ID_Start: "IDS",
        Ideographic: "Ideo",
        Join_Control: "Join_C",
        Logical_Order_Exception: "LOE",
        Lowercase: "Lower",
        Math: "Math",
        Noncharacter_Code_Point: "NChar",
        Pattern_Syntax: "Pat_Syn",
        Pattern_White_Space: "Pat_WS",
        Quotation_Mark: "QMark",
        Radical: "Radical",
        Regional_Indicator: "RI",
        Sentence_Terminal: "STerm",
        Soft_Dotted: "SD",
        Terminal_Punctuation: "Term",
        Unified_Ideograph: "UIdeo",
        Uppercase: "Upper",
        Variation_Selector: "VS",
        White_Space: "space",
        XID_Continue: "XIDC",
        XID_Start: "XIDS"
      };
      var BINARY_ALIASES_TO_PROP_NAMES = inverseMap(BINARY_PROP_NAMES_TO_ALIASES);
      var GENERAL_CATEGORY_VALUE_TO_ALIASES = {
        Cased_Letter: "LC",
        Close_Punctuation: "Pe",
        Connector_Punctuation: "Pc",
        Control: ["Cc", "cntrl"],
        Currency_Symbol: "Sc",
        Dash_Punctuation: "Pd",
        Decimal_Number: ["Nd", "digit"],
        Enclosing_Mark: "Me",
        Final_Punctuation: "Pf",
        Format: "Cf",
        Initial_Punctuation: "Pi",
        Letter: "L",
        Letter_Number: "Nl",
        Line_Separator: "Zl",
        Lowercase_Letter: "Ll",
        Mark: ["M", "Combining_Mark"],
        Math_Symbol: "Sm",
        Modifier_Letter: "Lm",
        Modifier_Symbol: "Sk",
        Nonspacing_Mark: "Mn",
        Number: "N",
        Open_Punctuation: "Ps",
        Other: "C",
        Other_Letter: "Lo",
        Other_Number: "No",
        Other_Punctuation: "Po",
        Other_Symbol: "So",
        Paragraph_Separator: "Zp",
        Private_Use: "Co",
        Punctuation: ["P", "punct"],
        Separator: "Z",
        Space_Separator: "Zs",
        Spacing_Mark: "Mc",
        Surrogate: "Cs",
        Symbol: "S",
        Titlecase_Letter: "Lt",
        Unassigned: "Cn",
        Uppercase_Letter: "Lu"
      };
      var GENERAL_CATEGORY_VALUE_ALIASES_TO_VALUES = inverseMap(GENERAL_CATEGORY_VALUE_TO_ALIASES);
      var SCRIPT_VALUE_TO_ALIASES = {
        Adlam: "Adlm",
        Ahom: "Ahom",
        Anatolian_Hieroglyphs: "Hluw",
        Arabic: "Arab",
        Armenian: "Armn",
        Avestan: "Avst",
        Balinese: "Bali",
        Bamum: "Bamu",
        Bassa_Vah: "Bass",
        Batak: "Batk",
        Bengali: "Beng",
        Bhaiksuki: "Bhks",
        Bopomofo: "Bopo",
        Brahmi: "Brah",
        Braille: "Brai",
        Buginese: "Bugi",
        Buhid: "Buhd",
        Canadian_Aboriginal: "Cans",
        Carian: "Cari",
        Caucasian_Albanian: "Aghb",
        Chakma: "Cakm",
        Cham: "Cham",
        Cherokee: "Cher",
        Common: "Zyyy",
        Coptic: ["Copt", "Qaac"],
        Cuneiform: "Xsux",
        Cypriot: "Cprt",
        Cyrillic: "Cyrl",
        Deseret: "Dsrt",
        Devanagari: "Deva",
        Dogra: "Dogr",
        Duployan: "Dupl",
        Egyptian_Hieroglyphs: "Egyp",
        Elbasan: "Elba",
        Ethiopic: "Ethi",
        Georgian: "Geor",
        Glagolitic: "Glag",
        Gothic: "Goth",
        Grantha: "Gran",
        Greek: "Grek",
        Gujarati: "Gujr",
        Gunjala_Gondi: "Gong",
        Gurmukhi: "Guru",
        Han: "Hani",
        Hangul: "Hang",
        Hanifi_Rohingya: "Rohg",
        Hanunoo: "Hano",
        Hatran: "Hatr",
        Hebrew: "Hebr",
        Hiragana: "Hira",
        Imperial_Aramaic: "Armi",
        Inherited: ["Zinh", "Qaai"],
        Inscriptional_Pahlavi: "Phli",
        Inscriptional_Parthian: "Prti",
        Javanese: "Java",
        Kaithi: "Kthi",
        Kannada: "Knda",
        Katakana: "Kana",
        Kayah_Li: "Kali",
        Kharoshthi: "Khar",
        Khmer: "Khmr",
        Khojki: "Khoj",
        Khudawadi: "Sind",
        Lao: "Laoo",
        Latin: "Latn",
        Lepcha: "Lepc",
        Limbu: "Limb",
        Linear_A: "Lina",
        Linear_B: "Linb",
        Lisu: "Lisu",
        Lycian: "Lyci",
        Lydian: "Lydi",
        Mahajani: "Mahj",
        Makasar: "Maka",
        Malayalam: "Mlym",
        Mandaic: "Mand",
        Manichaean: "Mani",
        Marchen: "Marc",
        Medefaidrin: "Medf",
        Masaram_Gondi: "Gonm",
        Meetei_Mayek: "Mtei",
        Mende_Kikakui: "Mend",
        Meroitic_Cursive: "Merc",
        Meroitic_Hieroglyphs: "Mero",
        Miao: "Plrd",
        Modi: "Modi",
        Mongolian: "Mong",
        Mro: "Mroo",
        Multani: "Mult",
        Myanmar: "Mymr",
        Nabataean: "Nbat",
        New_Tai_Lue: "Talu",
        Newa: "Newa",
        Nko: "Nkoo",
        Nushu: "Nshu",
        Ogham: "Ogam",
        Ol_Chiki: "Olck",
        Old_Hungarian: "Hung",
        Old_Italic: "Ital",
        Old_North_Arabian: "Narb",
        Old_Permic: "Perm",
        Old_Persian: "Xpeo",
        Old_Sogdian: "Sogo",
        Old_South_Arabian: "Sarb",
        Old_Turkic: "Orkh",
        Oriya: "Orya",
        Osage: "Osge",
        Osmanya: "Osma",
        Pahawh_Hmong: "Hmng",
        Palmyrene: "Palm",
        Pau_Cin_Hau: "Pauc",
        Phags_Pa: "Phag",
        Phoenician: "Phnx",
        Psalter_Pahlavi: "Phlp",
        Rejang: "Rjng",
        Runic: "Runr",
        Samaritan: "Samr",
        Saurashtra: "Saur",
        Sharada: "Shrd",
        Shavian: "Shaw",
        Siddham: "Sidd",
        SignWriting: "Sgnw",
        Sinhala: "Sinh",
        Sogdian: "Sogd",
        Sora_Sompeng: "Sora",
        Soyombo: "Soyo",
        Sundanese: "Sund",
        Syloti_Nagri: "Sylo",
        Syriac: "Syrc",
        Tagalog: "Tglg",
        Tagbanwa: "Tagb",
        Tai_Le: "Tale",
        Tai_Tham: "Lana",
        Tai_Viet: "Tavt",
        Takri: "Takr",
        Tamil: "Taml",
        Tangut: "Tang",
        Telugu: "Telu",
        Thaana: "Thaa",
        Thai: "Thai",
        Tibetan: "Tibt",
        Tifinagh: "Tfng",
        Tirhuta: "Tirh",
        Ugaritic: "Ugar",
        Vai: "Vaii",
        Warang_Citi: "Wara",
        Yi: "Yiii",
        Zanabazar_Square: "Zanb"
      };
      var SCRIPT_VALUE_ALIASES_TO_VALUE = inverseMap(SCRIPT_VALUE_TO_ALIASES);
      function inverseMap(data) {
        var inverse = {};
        for (var name in data) {
          if (!data.hasOwnProperty(name)) {
            continue;
          }
          var value = data[name];
          if (Array.isArray(value)) {
            for (var i = 0; i < value.length; i++) {
              inverse[value[i]] = name;
            }
          } else {
            inverse[value] = name;
          }
        }
        return inverse;
      }
      function isValidName(name) {
        return NON_BINARY_PROP_NAMES_TO_ALIASES.hasOwnProperty(name) || NON_BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(name) || BINARY_PROP_NAMES_TO_ALIASES.hasOwnProperty(name) || BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(name);
      }
      function isValidValue(name, value) {
        if (isGeneralCategoryName(name)) {
          return isGeneralCategoryValue(value);
        }
        if (isScriptCategoryName(name)) {
          return isScriptCategoryValue(value);
        }
        return false;
      }
      function isAlias(name) {
        return NON_BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(name) || BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(name);
      }
      function isGeneralCategoryName(name) {
        return name === "General_Category" || name == "gc";
      }
      function isScriptCategoryName(name) {
        return name === "Script" || name === "Script_Extensions" || name === "sc" || name === "scx";
      }
      function isGeneralCategoryValue(value) {
        return GENERAL_CATEGORY_VALUE_TO_ALIASES.hasOwnProperty(value) || GENERAL_CATEGORY_VALUE_ALIASES_TO_VALUES.hasOwnProperty(value);
      }
      function isScriptCategoryValue(value) {
        return SCRIPT_VALUE_TO_ALIASES.hasOwnProperty(value) || SCRIPT_VALUE_ALIASES_TO_VALUE.hasOwnProperty(value);
      }
      function isBinaryPropertyName(name) {
        return BINARY_PROP_NAMES_TO_ALIASES.hasOwnProperty(name) || BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(name);
      }
      function getCanonicalName(name) {
        if (NON_BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(name)) {
          return NON_BINARY_ALIASES_TO_PROP_NAMES[name];
        }
        if (BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(name)) {
          return BINARY_ALIASES_TO_PROP_NAMES[name];
        }
        return null;
      }
      function getCanonicalValue(value) {
        if (GENERAL_CATEGORY_VALUE_ALIASES_TO_VALUES.hasOwnProperty(value)) {
          return GENERAL_CATEGORY_VALUE_ALIASES_TO_VALUES[value];
        }
        if (SCRIPT_VALUE_ALIASES_TO_VALUE.hasOwnProperty(value)) {
          return SCRIPT_VALUE_ALIASES_TO_VALUE[value];
        }
        if (BINARY_ALIASES_TO_PROP_NAMES.hasOwnProperty(value)) {
          return BINARY_ALIASES_TO_PROP_NAMES[value];
        }
        return null;
      }
      module.exports = {
        isAlias,
        isValidName,
        isValidValue,
        isGeneralCategoryValue,
        isScriptCategoryValue,
        isBinaryPropertyName,
        getCanonicalName,
        getCanonicalValue,
        NON_BINARY_PROP_NAMES_TO_ALIASES,
        NON_BINARY_ALIASES_TO_PROP_NAMES,
        BINARY_PROP_NAMES_TO_ALIASES,
        BINARY_ALIASES_TO_PROP_NAMES,
        GENERAL_CATEGORY_VALUE_TO_ALIASES,
        GENERAL_CATEGORY_VALUE_ALIASES_TO_VALUES,
        SCRIPT_VALUE_TO_ALIASES,
        SCRIPT_VALUE_ALIASES_TO_VALUE
      };
    }
  });

  // node_modules/regexp-tree/dist/parser/generated/regexp-tree.js
  var require_regexp_tree = __commonJS({
    "node_modules/regexp-tree/dist/parser/generated/regexp-tree.js"(exports, module) {
      "use strict";
      var _slicedToArray = /* @__PURE__ */ (function() {
        function sliceIterator(arr, i) {
          var _arr = [];
          var _n = true;
          var _d = false;
          var _e = void 0;
          try {
            for (var _i = arr[Symbol.iterator](), _s; !(_n = (_s = _i.next()).done); _n = true) {
              _arr.push(_s.value);
              if (i && _arr.length === i) break;
            }
          } catch (err) {
            _d = true;
            _e = err;
          } finally {
            try {
              if (!_n && _i["return"]) _i["return"]();
            } finally {
              if (_d) throw _e;
            }
          }
          return _arr;
        }
        return function(arr, i) {
          if (Array.isArray(arr)) {
            return arr;
          } else if (Symbol.iterator in Object(arr)) {
            return sliceIterator(arr, i);
          } else {
            throw new TypeError("Invalid attempt to destructure non-iterable instance");
          }
        };
      })();
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      var yytext = void 0;
      var yyleng = void 0;
      var yy = {};
      var __ = void 0;
      var __loc = void 0;
      function yyloc(start, end) {
        if (!yy.options.captureLocations) {
          return null;
        }
        if (!start || !end) {
          return start || end;
        }
        return {
          startOffset: start.startOffset,
          endOffset: end.endOffset,
          startLine: start.startLine,
          endLine: end.endLine,
          startColumn: start.startColumn,
          endColumn: end.endColumn
        };
      }
      var EOF = "$";
      var productions = [[-1, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [0, 4, function(_1, _2, _3, _4, _1loc, _2loc, _3loc, _4loc) {
        __loc = yyloc(_1loc, _4loc);
        __ = Node2({
          type: "RegExp",
          body: _2,
          flags: checkFlags(_4)
        }, loc(_1loc, _4loc || _3loc));
      }], [1, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [1, 0, function() {
        __loc = null;
        __ = "";
      }], [2, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [2, 2, function(_1, _2, _1loc, _2loc) {
        __loc = yyloc(_1loc, _2loc);
        __ = _1 + _2;
      }], [3, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [4, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [4, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        var _loc = null;
        if (_2loc) {
          _loc = loc(_1loc || _2loc, _3loc || _2loc);
        }
        ;
        __ = Node2({
          type: "Disjunction",
          left: _1,
          right: _3
        }, _loc);
      }], [5, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        if (_1.length === 0) {
          __ = null;
          return;
        }
        if (_1.length === 1) {
          __ = Node2(_1[0], __loc);
        } else {
          __ = Node2({
            type: "Alternative",
            expressions: _1
          }, __loc);
        }
      }], [6, 0, function() {
        __loc = null;
        __ = [];
      }], [6, 2, function(_1, _2, _1loc, _2loc) {
        __loc = yyloc(_1loc, _2loc);
        __ = _1.concat(_2);
      }], [7, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Node2(Object.assign({ type: "Assertion" }, _1), __loc);
      }], [7, 2, function(_1, _2, _1loc, _2loc) {
        __loc = yyloc(_1loc, _2loc);
        __ = _1;
        if (_2) {
          __ = Node2({
            type: "Repetition",
            expression: _1,
            quantifier: _2
          }, __loc);
        }
      }], [8, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = { kind: "^" };
      }], [8, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = { kind: "$" };
      }], [8, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = { kind: "\\b" };
      }], [8, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = { kind: "\\B" };
      }], [8, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = {
          kind: "Lookahead",
          assertion: _2
        };
      }], [8, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = {
          kind: "Lookahead",
          negative: true,
          assertion: _2
        };
      }], [8, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = {
          kind: "Lookbehind",
          assertion: _2
        };
      }], [8, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = {
          kind: "Lookbehind",
          negative: true,
          assertion: _2
        };
      }], [9, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [9, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [9, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "simple", __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1.slice(1), "simple", __loc);
        __.escaped = true;
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "unicode", __loc);
        __.isSurrogatePair = true;
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "unicode", __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = UnicodeProperty(_1, __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "control", __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "hex", __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "oct", __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = GroupRefOrDecChar(_1, __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "meta", __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "meta", __loc);
      }], [10, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = NamedGroupRefOrChars(_1, _1loc);
      }], [11, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [11, 0], [12, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [12, 2, function(_1, _2, _1loc, _2loc) {
        __loc = yyloc(_1loc, _2loc);
        _1.greedy = false;
        __ = _1;
      }], [13, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Node2({
          type: "Quantifier",
          kind: _1,
          greedy: true
        }, __loc);
      }], [13, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Node2({
          type: "Quantifier",
          kind: _1,
          greedy: true
        }, __loc);
      }], [13, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Node2({
          type: "Quantifier",
          kind: _1,
          greedy: true
        }, __loc);
      }], [13, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        var range = getRange(_1);
        __ = Node2({
          type: "Quantifier",
          kind: "Range",
          from: range[0],
          to: range[0],
          greedy: true
        }, __loc);
      }], [13, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Node2({
          type: "Quantifier",
          kind: "Range",
          from: getRange(_1)[0],
          greedy: true
        }, __loc);
      }], [13, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        var range = getRange(_1);
        __ = Node2({
          type: "Quantifier",
          kind: "Range",
          from: range[0],
          to: range[1],
          greedy: true
        }, __loc);
      }], [14, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [14, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [15, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        var nameRaw = String(_1);
        var name = decodeUnicodeGroupName(nameRaw);
        if (!yy.options.allowGroupNameDuplicates && namedGroups.hasOwnProperty(name)) {
          throw new SyntaxError('Duplicate of the named group "' + name + '".');
        }
        namedGroups[name] = _1.groupNumber;
        __ = Node2({
          type: "Group",
          capturing: true,
          name,
          nameRaw,
          number: _1.groupNumber,
          expression: _2
        }, __loc);
      }], [15, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = Node2({
          type: "Group",
          capturing: true,
          number: _1.groupNumber,
          expression: _2
        }, __loc);
      }], [16, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = Node2({
          type: "Group",
          capturing: false,
          expression: _2
        }, __loc);
      }], [17, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = Node2({
          type: "CharacterClass",
          negative: true,
          expressions: _2
        }, __loc);
      }], [17, 3, function(_1, _2, _3, _1loc, _2loc, _3loc) {
        __loc = yyloc(_1loc, _3loc);
        __ = Node2({
          type: "CharacterClass",
          expressions: _2
        }, __loc);
      }], [18, 0, function() {
        __loc = null;
        __ = [];
      }], [18, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [19, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = [_1];
      }], [19, 2, function(_1, _2, _1loc, _2loc) {
        __loc = yyloc(_1loc, _2loc);
        __ = [_1].concat(_2);
      }], [19, 4, function(_1, _2, _3, _4, _1loc, _2loc, _3loc, _4loc) {
        __loc = yyloc(_1loc, _4loc);
        checkClassRange(_1, _3);
        __ = [Node2({
          type: "ClassRange",
          from: _1,
          to: _3
        }, loc(_1loc, _3loc))];
        if (_4) {
          __ = __.concat(_4);
        }
      }], [20, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [20, 2, function(_1, _2, _1loc, _2loc) {
        __loc = yyloc(_1loc, _2loc);
        __ = [_1].concat(_2);
      }], [20, 4, function(_1, _2, _3, _4, _1loc, _2loc, _3loc, _4loc) {
        __loc = yyloc(_1loc, _4loc);
        checkClassRange(_1, _3);
        __ = [Node2({
          type: "ClassRange",
          from: _1,
          to: _3
        }, loc(_1loc, _3loc))];
        if (_4) {
          __ = __.concat(_4);
        }
      }], [21, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "simple", __loc);
      }], [21, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [22, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = _1;
      }], [22, 1, function(_1, _1loc) {
        __loc = yyloc(_1loc, _1loc);
        __ = Char(_1, "meta", __loc);
      }]];
      var tokens = { "SLASH": "23", "CHAR": "24", "BAR": "25", "BOS": "26", "EOS": "27", "ESC_b": "28", "ESC_B": "29", "POS_LA_ASSERT": "30", "R_PAREN": "31", "NEG_LA_ASSERT": "32", "POS_LB_ASSERT": "33", "NEG_LB_ASSERT": "34", "ESC_CHAR": "35", "U_CODE_SURROGATE": "36", "U_CODE": "37", "U_PROP_VALUE_EXP": "38", "CTRL_CH": "39", "HEX_CODE": "40", "OCT_CODE": "41", "DEC_CODE": "42", "META_CHAR": "43", "ANY": "44", "NAMED_GROUP_REF": "45", "Q_MARK": "46", "STAR": "47", "PLUS": "48", "RANGE_EXACT": "49", "RANGE_OPEN": "50", "RANGE_CLOSED": "51", "NAMED_CAPTURE_GROUP": "52", "L_PAREN": "53", "NON_CAPTURE_GROUP": "54", "NEG_CLASS": "55", "R_BRACKET": "56", "L_BRACKET": "57", "DASH": "58", "$": "59" };
      var table = [{ "0": 1, "23": "s2" }, { "59": "acc" }, { "3": 3, "4": 4, "5": 5, "6": 6, "23": "r10", "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "23": "s7" }, { "23": "r6", "25": "s12" }, { "23": "r7", "25": "r7", "31": "r7" }, { "7": 14, "8": 15, "9": 16, "10": 25, "14": 27, "15": 42, "16": 43, "17": 26, "23": "r9", "24": "s28", "25": "r9", "26": "s17", "27": "s18", "28": "s19", "29": "s20", "30": "s21", "31": "r9", "32": "s22", "33": "s23", "34": "s24", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "52": "s44", "53": "s45", "54": "s46", "55": "s40", "57": "s41" }, { "1": 8, "2": 9, "24": "s10", "59": "r3" }, { "59": "r1" }, { "24": "s11", "59": "r2" }, { "24": "r4", "59": "r4" }, { "24": "r5", "59": "r5" }, { "5": 13, "6": 6, "23": "r10", "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "23": "r8", "25": "r8", "31": "r8" }, { "23": "r11", "24": "r11", "25": "r11", "26": "r11", "27": "r11", "28": "r11", "29": "r11", "30": "r11", "31": "r11", "32": "r11", "33": "r11", "34": "r11", "35": "r11", "36": "r11", "37": "r11", "38": "r11", "39": "r11", "40": "r11", "41": "r11", "42": "r11", "43": "r11", "44": "r11", "45": "r11", "52": "r11", "53": "r11", "54": "r11", "55": "r11", "57": "r11" }, { "23": "r12", "24": "r12", "25": "r12", "26": "r12", "27": "r12", "28": "r12", "29": "r12", "30": "r12", "31": "r12", "32": "r12", "33": "r12", "34": "r12", "35": "r12", "36": "r12", "37": "r12", "38": "r12", "39": "r12", "40": "r12", "41": "r12", "42": "r12", "43": "r12", "44": "r12", "45": "r12", "52": "r12", "53": "r12", "54": "r12", "55": "r12", "57": "r12" }, { "11": 47, "12": 48, "13": 49, "23": "r38", "24": "r38", "25": "r38", "26": "r38", "27": "r38", "28": "r38", "29": "r38", "30": "r38", "31": "r38", "32": "r38", "33": "r38", "34": "r38", "35": "r38", "36": "r38", "37": "r38", "38": "r38", "39": "r38", "40": "r38", "41": "r38", "42": "r38", "43": "r38", "44": "r38", "45": "r38", "46": "s52", "47": "s50", "48": "s51", "49": "s53", "50": "s54", "51": "s55", "52": "r38", "53": "r38", "54": "r38", "55": "r38", "57": "r38" }, { "23": "r14", "24": "r14", "25": "r14", "26": "r14", "27": "r14", "28": "r14", "29": "r14", "30": "r14", "31": "r14", "32": "r14", "33": "r14", "34": "r14", "35": "r14", "36": "r14", "37": "r14", "38": "r14", "39": "r14", "40": "r14", "41": "r14", "42": "r14", "43": "r14", "44": "r14", "45": "r14", "52": "r14", "53": "r14", "54": "r14", "55": "r14", "57": "r14" }, { "23": "r15", "24": "r15", "25": "r15", "26": "r15", "27": "r15", "28": "r15", "29": "r15", "30": "r15", "31": "r15", "32": "r15", "33": "r15", "34": "r15", "35": "r15", "36": "r15", "37": "r15", "38": "r15", "39": "r15", "40": "r15", "41": "r15", "42": "r15", "43": "r15", "44": "r15", "45": "r15", "52": "r15", "53": "r15", "54": "r15", "55": "r15", "57": "r15" }, { "23": "r16", "24": "r16", "25": "r16", "26": "r16", "27": "r16", "28": "r16", "29": "r16", "30": "r16", "31": "r16", "32": "r16", "33": "r16", "34": "r16", "35": "r16", "36": "r16", "37": "r16", "38": "r16", "39": "r16", "40": "r16", "41": "r16", "42": "r16", "43": "r16", "44": "r16", "45": "r16", "52": "r16", "53": "r16", "54": "r16", "55": "r16", "57": "r16" }, { "23": "r17", "24": "r17", "25": "r17", "26": "r17", "27": "r17", "28": "r17", "29": "r17", "30": "r17", "31": "r17", "32": "r17", "33": "r17", "34": "r17", "35": "r17", "36": "r17", "37": "r17", "38": "r17", "39": "r17", "40": "r17", "41": "r17", "42": "r17", "43": "r17", "44": "r17", "45": "r17", "52": "r17", "53": "r17", "54": "r17", "55": "r17", "57": "r17" }, { "4": 57, "5": 5, "6": 6, "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "4": 59, "5": 5, "6": 6, "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "4": 61, "5": 5, "6": 6, "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "4": 63, "5": 5, "6": 6, "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "23": "r22", "24": "r22", "25": "r22", "26": "r22", "27": "r22", "28": "r22", "29": "r22", "30": "r22", "31": "r22", "32": "r22", "33": "r22", "34": "r22", "35": "r22", "36": "r22", "37": "r22", "38": "r22", "39": "r22", "40": "r22", "41": "r22", "42": "r22", "43": "r22", "44": "r22", "45": "r22", "46": "r22", "47": "r22", "48": "r22", "49": "r22", "50": "r22", "51": "r22", "52": "r22", "53": "r22", "54": "r22", "55": "r22", "57": "r22" }, { "23": "r23", "24": "r23", "25": "r23", "26": "r23", "27": "r23", "28": "r23", "29": "r23", "30": "r23", "31": "r23", "32": "r23", "33": "r23", "34": "r23", "35": "r23", "36": "r23", "37": "r23", "38": "r23", "39": "r23", "40": "r23", "41": "r23", "42": "r23", "43": "r23", "44": "r23", "45": "r23", "46": "r23", "47": "r23", "48": "r23", "49": "r23", "50": "r23", "51": "r23", "52": "r23", "53": "r23", "54": "r23", "55": "r23", "57": "r23" }, { "23": "r24", "24": "r24", "25": "r24", "26": "r24", "27": "r24", "28": "r24", "29": "r24", "30": "r24", "31": "r24", "32": "r24", "33": "r24", "34": "r24", "35": "r24", "36": "r24", "37": "r24", "38": "r24", "39": "r24", "40": "r24", "41": "r24", "42": "r24", "43": "r24", "44": "r24", "45": "r24", "46": "r24", "47": "r24", "48": "r24", "49": "r24", "50": "r24", "51": "r24", "52": "r24", "53": "r24", "54": "r24", "55": "r24", "57": "r24" }, { "23": "r25", "24": "r25", "25": "r25", "26": "r25", "27": "r25", "28": "r25", "29": "r25", "30": "r25", "31": "r25", "32": "r25", "33": "r25", "34": "r25", "35": "r25", "36": "r25", "37": "r25", "38": "r25", "39": "r25", "40": "r25", "41": "r25", "42": "r25", "43": "r25", "44": "r25", "45": "r25", "46": "r25", "47": "r25", "48": "r25", "49": "r25", "50": "r25", "51": "r25", "52": "r25", "53": "r25", "54": "r25", "55": "r25", "56": "r25", "57": "r25", "58": "r25" }, { "23": "r26", "24": "r26", "25": "r26", "26": "r26", "27": "r26", "28": "r26", "29": "r26", "30": "r26", "31": "r26", "32": "r26", "33": "r26", "34": "r26", "35": "r26", "36": "r26", "37": "r26", "38": "r26", "39": "r26", "40": "r26", "41": "r26", "42": "r26", "43": "r26", "44": "r26", "45": "r26", "46": "r26", "47": "r26", "48": "r26", "49": "r26", "50": "r26", "51": "r26", "52": "r26", "53": "r26", "54": "r26", "55": "r26", "56": "r26", "57": "r26", "58": "r26" }, { "23": "r27", "24": "r27", "25": "r27", "26": "r27", "27": "r27", "28": "r27", "29": "r27", "30": "r27", "31": "r27", "32": "r27", "33": "r27", "34": "r27", "35": "r27", "36": "r27", "37": "r27", "38": "r27", "39": "r27", "40": "r27", "41": "r27", "42": "r27", "43": "r27", "44": "r27", "45": "r27", "46": "r27", "47": "r27", "48": "r27", "49": "r27", "50": "r27", "51": "r27", "52": "r27", "53": "r27", "54": "r27", "55": "r27", "56": "r27", "57": "r27", "58": "r27" }, { "23": "r28", "24": "r28", "25": "r28", "26": "r28", "27": "r28", "28": "r28", "29": "r28", "30": "r28", "31": "r28", "32": "r28", "33": "r28", "34": "r28", "35": "r28", "36": "r28", "37": "r28", "38": "r28", "39": "r28", "40": "r28", "41": "r28", "42": "r28", "43": "r28", "44": "r28", "45": "r28", "46": "r28", "47": "r28", "48": "r28", "49": "r28", "50": "r28", "51": "r28", "52": "r28", "53": "r28", "54": "r28", "55": "r28", "56": "r28", "57": "r28", "58": "r28" }, { "23": "r29", "24": "r29", "25": "r29", "26": "r29", "27": "r29", "28": "r29", "29": "r29", "30": "r29", "31": "r29", "32": "r29", "33": "r29", "34": "r29", "35": "r29", "36": "r29", "37": "r29", "38": "r29", "39": "r29", "40": "r29", "41": "r29", "42": "r29", "43": "r29", "44": "r29", "45": "r29", "46": "r29", "47": "r29", "48": "r29", "49": "r29", "50": "r29", "51": "r29", "52": "r29", "53": "r29", "54": "r29", "55": "r29", "56": "r29", "57": "r29", "58": "r29" }, { "23": "r30", "24": "r30", "25": "r30", "26": "r30", "27": "r30", "28": "r30", "29": "r30", "30": "r30", "31": "r30", "32": "r30", "33": "r30", "34": "r30", "35": "r30", "36": "r30", "37": "r30", "38": "r30", "39": "r30", "40": "r30", "41": "r30", "42": "r30", "43": "r30", "44": "r30", "45": "r30", "46": "r30", "47": "r30", "48": "r30", "49": "r30", "50": "r30", "51": "r30", "52": "r30", "53": "r30", "54": "r30", "55": "r30", "56": "r30", "57": "r30", "58": "r30" }, { "23": "r31", "24": "r31", "25": "r31", "26": "r31", "27": "r31", "28": "r31", "29": "r31", "30": "r31", "31": "r31", "32": "r31", "33": "r31", "34": "r31", "35": "r31", "36": "r31", "37": "r31", "38": "r31", "39": "r31", "40": "r31", "41": "r31", "42": "r31", "43": "r31", "44": "r31", "45": "r31", "46": "r31", "47": "r31", "48": "r31", "49": "r31", "50": "r31", "51": "r31", "52": "r31", "53": "r31", "54": "r31", "55": "r31", "56": "r31", "57": "r31", "58": "r31" }, { "23": "r32", "24": "r32", "25": "r32", "26": "r32", "27": "r32", "28": "r32", "29": "r32", "30": "r32", "31": "r32", "32": "r32", "33": "r32", "34": "r32", "35": "r32", "36": "r32", "37": "r32", "38": "r32", "39": "r32", "40": "r32", "41": "r32", "42": "r32", "43": "r32", "44": "r32", "45": "r32", "46": "r32", "47": "r32", "48": "r32", "49": "r32", "50": "r32", "51": "r32", "52": "r32", "53": "r32", "54": "r32", "55": "r32", "56": "r32", "57": "r32", "58": "r32" }, { "23": "r33", "24": "r33", "25": "r33", "26": "r33", "27": "r33", "28": "r33", "29": "r33", "30": "r33", "31": "r33", "32": "r33", "33": "r33", "34": "r33", "35": "r33", "36": "r33", "37": "r33", "38": "r33", "39": "r33", "40": "r33", "41": "r33", "42": "r33", "43": "r33", "44": "r33", "45": "r33", "46": "r33", "47": "r33", "48": "r33", "49": "r33", "50": "r33", "51": "r33", "52": "r33", "53": "r33", "54": "r33", "55": "r33", "56": "r33", "57": "r33", "58": "r33" }, { "23": "r34", "24": "r34", "25": "r34", "26": "r34", "27": "r34", "28": "r34", "29": "r34", "30": "r34", "31": "r34", "32": "r34", "33": "r34", "34": "r34", "35": "r34", "36": "r34", "37": "r34", "38": "r34", "39": "r34", "40": "r34", "41": "r34", "42": "r34", "43": "r34", "44": "r34", "45": "r34", "46": "r34", "47": "r34", "48": "r34", "49": "r34", "50": "r34", "51": "r34", "52": "r34", "53": "r34", "54": "r34", "55": "r34", "56": "r34", "57": "r34", "58": "r34" }, { "23": "r35", "24": "r35", "25": "r35", "26": "r35", "27": "r35", "28": "r35", "29": "r35", "30": "r35", "31": "r35", "32": "r35", "33": "r35", "34": "r35", "35": "r35", "36": "r35", "37": "r35", "38": "r35", "39": "r35", "40": "r35", "41": "r35", "42": "r35", "43": "r35", "44": "r35", "45": "r35", "46": "r35", "47": "r35", "48": "r35", "49": "r35", "50": "r35", "51": "r35", "52": "r35", "53": "r35", "54": "r35", "55": "r35", "56": "r35", "57": "r35", "58": "r35" }, { "23": "r36", "24": "r36", "25": "r36", "26": "r36", "27": "r36", "28": "r36", "29": "r36", "30": "r36", "31": "r36", "32": "r36", "33": "r36", "34": "r36", "35": "r36", "36": "r36", "37": "r36", "38": "r36", "39": "r36", "40": "r36", "41": "r36", "42": "r36", "43": "r36", "44": "r36", "45": "r36", "46": "r36", "47": "r36", "48": "r36", "49": "r36", "50": "r36", "51": "r36", "52": "r36", "53": "r36", "54": "r36", "55": "r36", "56": "r36", "57": "r36", "58": "r36" }, { "10": 70, "18": 65, "19": 66, "21": 67, "22": 69, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r54", "58": "s68" }, { "10": 70, "18": 83, "19": 66, "21": 67, "22": 69, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r54", "58": "s68" }, { "23": "r47", "24": "r47", "25": "r47", "26": "r47", "27": "r47", "28": "r47", "29": "r47", "30": "r47", "31": "r47", "32": "r47", "33": "r47", "34": "r47", "35": "r47", "36": "r47", "37": "r47", "38": "r47", "39": "r47", "40": "r47", "41": "r47", "42": "r47", "43": "r47", "44": "r47", "45": "r47", "46": "r47", "47": "r47", "48": "r47", "49": "r47", "50": "r47", "51": "r47", "52": "r47", "53": "r47", "54": "r47", "55": "r47", "57": "r47" }, { "23": "r48", "24": "r48", "25": "r48", "26": "r48", "27": "r48", "28": "r48", "29": "r48", "30": "r48", "31": "r48", "32": "r48", "33": "r48", "34": "r48", "35": "r48", "36": "r48", "37": "r48", "38": "r48", "39": "r48", "40": "r48", "41": "r48", "42": "r48", "43": "r48", "44": "r48", "45": "r48", "46": "r48", "47": "r48", "48": "r48", "49": "r48", "50": "r48", "51": "r48", "52": "r48", "53": "r48", "54": "r48", "55": "r48", "57": "r48" }, { "4": 85, "5": 5, "6": 6, "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "4": 87, "5": 5, "6": 6, "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "4": 89, "5": 5, "6": 6, "24": "r10", "25": "r10", "26": "r10", "27": "r10", "28": "r10", "29": "r10", "30": "r10", "31": "r10", "32": "r10", "33": "r10", "34": "r10", "35": "r10", "36": "r10", "37": "r10", "38": "r10", "39": "r10", "40": "r10", "41": "r10", "42": "r10", "43": "r10", "44": "r10", "45": "r10", "52": "r10", "53": "r10", "54": "r10", "55": "r10", "57": "r10" }, { "23": "r13", "24": "r13", "25": "r13", "26": "r13", "27": "r13", "28": "r13", "29": "r13", "30": "r13", "31": "r13", "32": "r13", "33": "r13", "34": "r13", "35": "r13", "36": "r13", "37": "r13", "38": "r13", "39": "r13", "40": "r13", "41": "r13", "42": "r13", "43": "r13", "44": "r13", "45": "r13", "52": "r13", "53": "r13", "54": "r13", "55": "r13", "57": "r13" }, { "23": "r37", "24": "r37", "25": "r37", "26": "r37", "27": "r37", "28": "r37", "29": "r37", "30": "r37", "31": "r37", "32": "r37", "33": "r37", "34": "r37", "35": "r37", "36": "r37", "37": "r37", "38": "r37", "39": "r37", "40": "r37", "41": "r37", "42": "r37", "43": "r37", "44": "r37", "45": "r37", "52": "r37", "53": "r37", "54": "r37", "55": "r37", "57": "r37" }, { "23": "r39", "24": "r39", "25": "r39", "26": "r39", "27": "r39", "28": "r39", "29": "r39", "30": "r39", "31": "r39", "32": "r39", "33": "r39", "34": "r39", "35": "r39", "36": "r39", "37": "r39", "38": "r39", "39": "r39", "40": "r39", "41": "r39", "42": "r39", "43": "r39", "44": "r39", "45": "r39", "46": "s56", "52": "r39", "53": "r39", "54": "r39", "55": "r39", "57": "r39" }, { "23": "r41", "24": "r41", "25": "r41", "26": "r41", "27": "r41", "28": "r41", "29": "r41", "30": "r41", "31": "r41", "32": "r41", "33": "r41", "34": "r41", "35": "r41", "36": "r41", "37": "r41", "38": "r41", "39": "r41", "40": "r41", "41": "r41", "42": "r41", "43": "r41", "44": "r41", "45": "r41", "46": "r41", "52": "r41", "53": "r41", "54": "r41", "55": "r41", "57": "r41" }, { "23": "r42", "24": "r42", "25": "r42", "26": "r42", "27": "r42", "28": "r42", "29": "r42", "30": "r42", "31": "r42", "32": "r42", "33": "r42", "34": "r42", "35": "r42", "36": "r42", "37": "r42", "38": "r42", "39": "r42", "40": "r42", "41": "r42", "42": "r42", "43": "r42", "44": "r42", "45": "r42", "46": "r42", "52": "r42", "53": "r42", "54": "r42", "55": "r42", "57": "r42" }, { "23": "r43", "24": "r43", "25": "r43", "26": "r43", "27": "r43", "28": "r43", "29": "r43", "30": "r43", "31": "r43", "32": "r43", "33": "r43", "34": "r43", "35": "r43", "36": "r43", "37": "r43", "38": "r43", "39": "r43", "40": "r43", "41": "r43", "42": "r43", "43": "r43", "44": "r43", "45": "r43", "46": "r43", "52": "r43", "53": "r43", "54": "r43", "55": "r43", "57": "r43" }, { "23": "r44", "24": "r44", "25": "r44", "26": "r44", "27": "r44", "28": "r44", "29": "r44", "30": "r44", "31": "r44", "32": "r44", "33": "r44", "34": "r44", "35": "r44", "36": "r44", "37": "r44", "38": "r44", "39": "r44", "40": "r44", "41": "r44", "42": "r44", "43": "r44", "44": "r44", "45": "r44", "46": "r44", "52": "r44", "53": "r44", "54": "r44", "55": "r44", "57": "r44" }, { "23": "r45", "24": "r45", "25": "r45", "26": "r45", "27": "r45", "28": "r45", "29": "r45", "30": "r45", "31": "r45", "32": "r45", "33": "r45", "34": "r45", "35": "r45", "36": "r45", "37": "r45", "38": "r45", "39": "r45", "40": "r45", "41": "r45", "42": "r45", "43": "r45", "44": "r45", "45": "r45", "46": "r45", "52": "r45", "53": "r45", "54": "r45", "55": "r45", "57": "r45" }, { "23": "r46", "24": "r46", "25": "r46", "26": "r46", "27": "r46", "28": "r46", "29": "r46", "30": "r46", "31": "r46", "32": "r46", "33": "r46", "34": "r46", "35": "r46", "36": "r46", "37": "r46", "38": "r46", "39": "r46", "40": "r46", "41": "r46", "42": "r46", "43": "r46", "44": "r46", "45": "r46", "46": "r46", "52": "r46", "53": "r46", "54": "r46", "55": "r46", "57": "r46" }, { "23": "r40", "24": "r40", "25": "r40", "26": "r40", "27": "r40", "28": "r40", "29": "r40", "30": "r40", "31": "r40", "32": "r40", "33": "r40", "34": "r40", "35": "r40", "36": "r40", "37": "r40", "38": "r40", "39": "r40", "40": "r40", "41": "r40", "42": "r40", "43": "r40", "44": "r40", "45": "r40", "52": "r40", "53": "r40", "54": "r40", "55": "r40", "57": "r40" }, { "25": "s12", "31": "s58" }, { "23": "r18", "24": "r18", "25": "r18", "26": "r18", "27": "r18", "28": "r18", "29": "r18", "30": "r18", "31": "r18", "32": "r18", "33": "r18", "34": "r18", "35": "r18", "36": "r18", "37": "r18", "38": "r18", "39": "r18", "40": "r18", "41": "r18", "42": "r18", "43": "r18", "44": "r18", "45": "r18", "52": "r18", "53": "r18", "54": "r18", "55": "r18", "57": "r18" }, { "25": "s12", "31": "s60" }, { "23": "r19", "24": "r19", "25": "r19", "26": "r19", "27": "r19", "28": "r19", "29": "r19", "30": "r19", "31": "r19", "32": "r19", "33": "r19", "34": "r19", "35": "r19", "36": "r19", "37": "r19", "38": "r19", "39": "r19", "40": "r19", "41": "r19", "42": "r19", "43": "r19", "44": "r19", "45": "r19", "52": "r19", "53": "r19", "54": "r19", "55": "r19", "57": "r19" }, { "25": "s12", "31": "s62" }, { "23": "r20", "24": "r20", "25": "r20", "26": "r20", "27": "r20", "28": "r20", "29": "r20", "30": "r20", "31": "r20", "32": "r20", "33": "r20", "34": "r20", "35": "r20", "36": "r20", "37": "r20", "38": "r20", "39": "r20", "40": "r20", "41": "r20", "42": "r20", "43": "r20", "44": "r20", "45": "r20", "52": "r20", "53": "r20", "54": "r20", "55": "r20", "57": "r20" }, { "25": "s12", "31": "s64" }, { "23": "r21", "24": "r21", "25": "r21", "26": "r21", "27": "r21", "28": "r21", "29": "r21", "30": "r21", "31": "r21", "32": "r21", "33": "r21", "34": "r21", "35": "r21", "36": "r21", "37": "r21", "38": "r21", "39": "r21", "40": "r21", "41": "r21", "42": "r21", "43": "r21", "44": "r21", "45": "r21", "52": "r21", "53": "r21", "54": "r21", "55": "r21", "57": "r21" }, { "56": "s72" }, { "56": "r55" }, { "10": 70, "20": 73, "21": 75, "22": 76, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r56", "58": "s74" }, { "24": "r62", "28": "r62", "35": "r62", "36": "r62", "37": "r62", "38": "r62", "39": "r62", "40": "r62", "41": "r62", "42": "r62", "43": "r62", "44": "r62", "45": "r62", "56": "r62", "58": "r62" }, { "24": "r63", "28": "r63", "35": "r63", "36": "r63", "37": "r63", "38": "r63", "39": "r63", "40": "r63", "41": "r63", "42": "r63", "43": "r63", "44": "r63", "45": "r63", "56": "r63", "58": "r63" }, { "24": "r64", "28": "r64", "35": "r64", "36": "r64", "37": "r64", "38": "r64", "39": "r64", "40": "r64", "41": "r64", "42": "r64", "43": "r64", "44": "r64", "45": "r64", "56": "r64", "58": "r64" }, { "24": "r65", "28": "r65", "35": "r65", "36": "r65", "37": "r65", "38": "r65", "39": "r65", "40": "r65", "41": "r65", "42": "r65", "43": "r65", "44": "r65", "45": "r65", "56": "r65", "58": "r65" }, { "23": "r52", "24": "r52", "25": "r52", "26": "r52", "27": "r52", "28": "r52", "29": "r52", "30": "r52", "31": "r52", "32": "r52", "33": "r52", "34": "r52", "35": "r52", "36": "r52", "37": "r52", "38": "r52", "39": "r52", "40": "r52", "41": "r52", "42": "r52", "43": "r52", "44": "r52", "45": "r52", "46": "r52", "47": "r52", "48": "r52", "49": "r52", "50": "r52", "51": "r52", "52": "r52", "53": "r52", "54": "r52", "55": "r52", "57": "r52" }, { "56": "r57" }, { "10": 70, "21": 77, "22": 69, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r62", "58": "s68" }, { "56": "r59" }, { "10": 70, "20": 79, "21": 75, "22": 76, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r63", "58": "s80" }, { "10": 70, "18": 78, "19": 66, "21": 67, "22": 69, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r54", "58": "s68" }, { "56": "r58" }, { "56": "r60" }, { "10": 70, "21": 81, "22": 69, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r62", "58": "s68" }, { "10": 70, "18": 82, "19": 66, "21": 67, "22": 69, "24": "s28", "28": "s71", "35": "s29", "36": "s30", "37": "s31", "38": "s32", "39": "s33", "40": "s34", "41": "s35", "42": "s36", "43": "s37", "44": "s38", "45": "s39", "56": "r54", "58": "s68" }, { "56": "r61" }, { "56": "s84" }, { "23": "r53", "24": "r53", "25": "r53", "26": "r53", "27": "r53", "28": "r53", "29": "r53", "30": "r53", "31": "r53", "32": "r53", "33": "r53", "34": "r53", "35": "r53", "36": "r53", "37": "r53", "38": "r53", "39": "r53", "40": "r53", "41": "r53", "42": "r53", "43": "r53", "44": "r53", "45": "r53", "46": "r53", "47": "r53", "48": "r53", "49": "r53", "50": "r53", "51": "r53", "52": "r53", "53": "r53", "54": "r53", "55": "r53", "57": "r53" }, { "25": "s12", "31": "s86" }, { "23": "r49", "24": "r49", "25": "r49", "26": "r49", "27": "r49", "28": "r49", "29": "r49", "30": "r49", "31": "r49", "32": "r49", "33": "r49", "34": "r49", "35": "r49", "36": "r49", "37": "r49", "38": "r49", "39": "r49", "40": "r49", "41": "r49", "42": "r49", "43": "r49", "44": "r49", "45": "r49", "46": "r49", "47": "r49", "48": "r49", "49": "r49", "50": "r49", "51": "r49", "52": "r49", "53": "r49", "54": "r49", "55": "r49", "57": "r49" }, { "25": "s12", "31": "s88" }, { "23": "r50", "24": "r50", "25": "r50", "26": "r50", "27": "r50", "28": "r50", "29": "r50", "30": "r50", "31": "r50", "32": "r50", "33": "r50", "34": "r50", "35": "r50", "36": "r50", "37": "r50", "38": "r50", "39": "r50", "40": "r50", "41": "r50", "42": "r50", "43": "r50", "44": "r50", "45": "r50", "46": "r50", "47": "r50", "48": "r50", "49": "r50", "50": "r50", "51": "r50", "52": "r50", "53": "r50", "54": "r50", "55": "r50", "57": "r50" }, { "25": "s12", "31": "s90" }, { "23": "r51", "24": "r51", "25": "r51", "26": "r51", "27": "r51", "28": "r51", "29": "r51", "30": "r51", "31": "r51", "32": "r51", "33": "r51", "34": "r51", "35": "r51", "36": "r51", "37": "r51", "38": "r51", "39": "r51", "40": "r51", "41": "r51", "42": "r51", "43": "r51", "44": "r51", "45": "r51", "46": "r51", "47": "r51", "48": "r51", "49": "r51", "50": "r51", "51": "r51", "52": "r51", "53": "r51", "54": "r51", "55": "r51", "57": "r51" }];
      var stack = [];
      var tokenizer = void 0;
      var lexRules = [[/^#[^\n]+/, function() {
      }], [/^\s+/, function() {
      }], [/^-/, function() {
        return "DASH";
      }], [/^\//, function() {
        return "CHAR";
      }], [/^#/, function() {
        return "CHAR";
      }], [/^\|/, function() {
        return "CHAR";
      }], [/^\./, function() {
        return "CHAR";
      }], [/^\{/, function() {
        return "CHAR";
      }], [/^\{\d+\}/, function() {
        return "RANGE_EXACT";
      }], [/^\{\d+,\}/, function() {
        return "RANGE_OPEN";
      }], [/^\{\d+,\d+\}/, function() {
        return "RANGE_CLOSED";
      }], [/^\\k<(([\u0041-\u005a\u0061-\u007a\u00aa\u00b5\u00ba\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u02c1\u02c6-\u02d1\u02e0-\u02e4\u02ec\u02ee\u0370-\u0374\u0376-\u0377\u037a-\u037d\u037f\u0386\u0388-\u038a\u038c\u038e-\u03a1\u03a3-\u03f5\u03f7-\u0481\u048a-\u052f\u0531-\u0556\u0559\u0560-\u0588\u05d0-\u05ea\u05ef-\u05f2\u0620-\u064a\u066e-\u066f\u0671-\u06d3\u06d5\u06e5-\u06e6\u06ee-\u06ef\u06fa-\u06fc\u06ff\u0710\u0712-\u072f\u074d-\u07a5\u07b1\u07ca-\u07ea\u07f4-\u07f5\u07fa\u0800-\u0815\u081a\u0824\u0828\u0840-\u0858\u0860-\u086a\u08a0-\u08b4\u08b6-\u08bd\u0904-\u0939\u093d\u0950\u0958-\u0961\u0971-\u0980\u0985-\u098c\u098f-\u0990\u0993-\u09a8\u09aa-\u09b0\u09b2\u09b6-\u09b9\u09bd\u09ce\u09dc-\u09dd\u09df-\u09e1\u09f0-\u09f1\u09fc\u0a05-\u0a0a\u0a0f-\u0a10\u0a13-\u0a28\u0a2a-\u0a30\u0a32-\u0a33\u0a35-\u0a36\u0a38-\u0a39\u0a59-\u0a5c\u0a5e\u0a72-\u0a74\u0a85-\u0a8d\u0a8f-\u0a91\u0a93-\u0aa8\u0aaa-\u0ab0\u0ab2-\u0ab3\u0ab5-\u0ab9\u0abd\u0ad0\u0ae0-\u0ae1\u0af9\u0b05-\u0b0c\u0b0f-\u0b10\u0b13-\u0b28\u0b2a-\u0b30\u0b32-\u0b33\u0b35-\u0b39\u0b3d\u0b5c-\u0b5d\u0b5f-\u0b61\u0b71\u0b83\u0b85-\u0b8a\u0b8e-\u0b90\u0b92-\u0b95\u0b99-\u0b9a\u0b9c\u0b9e-\u0b9f\u0ba3-\u0ba4\u0ba8-\u0baa\u0bae-\u0bb9\u0bd0\u0c05-\u0c0c\u0c0e-\u0c10\u0c12-\u0c28\u0c2a-\u0c39\u0c3d\u0c58-\u0c5a\u0c60-\u0c61\u0c80\u0c85-\u0c8c\u0c8e-\u0c90\u0c92-\u0ca8\u0caa-\u0cb3\u0cb5-\u0cb9\u0cbd\u0cde\u0ce0-\u0ce1\u0cf1-\u0cf2\u0d05-\u0d0c\u0d0e-\u0d10\u0d12-\u0d3a\u0d3d\u0d4e\u0d54-\u0d56\u0d5f-\u0d61\u0d7a-\u0d7f\u0d85-\u0d96\u0d9a-\u0db1\u0db3-\u0dbb\u0dbd\u0dc0-\u0dc6\u0e01-\u0e30\u0e32-\u0e33\u0e40-\u0e46\u0e81-\u0e82\u0e84\u0e86-\u0e8a\u0e8c-\u0ea3\u0ea5\u0ea7-\u0eb0\u0eb2-\u0eb3\u0ebd\u0ec0-\u0ec4\u0ec6\u0edc-\u0edf\u0f00\u0f40-\u0f47\u0f49-\u0f6c\u0f88-\u0f8c\u1000-\u102a\u103f\u1050-\u1055\u105a-\u105d\u1061\u1065-\u1066\u106e-\u1070\u1075-\u1081\u108e\u10a0-\u10c5\u10c7\u10cd\u10d0-\u10fa\u10fc-\u1248\u124a-\u124d\u1250-\u1256\u1258\u125a-\u125d\u1260-\u1288\u128a-\u128d\u1290-\u12b0\u12b2-\u12b5\u12b8-\u12be\u12c0\u12c2-\u12c5\u12c8-\u12d6\u12d8-\u1310\u1312-\u1315\u1318-\u135a\u1380-\u138f\u13a0-\u13f5\u13f8-\u13fd\u1401-\u166c\u166f-\u167f\u1681-\u169a\u16a0-\u16ea\u16ee-\u16f8\u1700-\u170c\u170e-\u1711\u1720-\u1731\u1740-\u1751\u1760-\u176c\u176e-\u1770\u1780-\u17b3\u17d7\u17dc\u1820-\u1878\u1880-\u18a8\u18aa\u18b0-\u18f5\u1900-\u191e\u1950-\u196d\u1970-\u1974\u1980-\u19ab\u19b0-\u19c9\u1a00-\u1a16\u1a20-\u1a54\u1aa7\u1b05-\u1b33\u1b45-\u1b4b\u1b83-\u1ba0\u1bae-\u1baf\u1bba-\u1be5\u1c00-\u1c23\u1c4d-\u1c4f\u1c5a-\u1c7d\u1c80-\u1c88\u1c90-\u1cba\u1cbd-\u1cbf\u1ce9-\u1cec\u1cee-\u1cf3\u1cf5-\u1cf6\u1cfa\u1d00-\u1dbf\u1e00-\u1f15\u1f18-\u1f1d\u1f20-\u1f45\u1f48-\u1f4d\u1f50-\u1f57\u1f59\u1f5b\u1f5d\u1f5f-\u1f7d\u1f80-\u1fb4\u1fb6-\u1fbc\u1fbe\u1fc2-\u1fc4\u1fc6-\u1fcc\u1fd0-\u1fd3\u1fd6-\u1fdb\u1fe0-\u1fec\u1ff2-\u1ff4\u1ff6-\u1ffc\u2071\u207f\u2090-\u209c\u2102\u2107\u210a-\u2113\u2115\u2118-\u211d\u2124\u2126\u2128\u212a-\u2139\u213c-\u213f\u2145-\u2149\u214e\u2160-\u2188\u2c00-\u2c2e\u2c30-\u2c5e\u2c60-\u2ce4\u2ceb-\u2cee\u2cf2-\u2cf3\u2d00-\u2d25\u2d27\u2d2d\u2d30-\u2d67\u2d6f\u2d80-\u2d96\u2da0-\u2da6\u2da8-\u2dae\u2db0-\u2db6\u2db8-\u2dbe\u2dc0-\u2dc6\u2dc8-\u2dce\u2dd0-\u2dd6\u2dd8-\u2dde\u3005-\u3007\u3021-\u3029\u3031-\u3035\u3038-\u303c\u3041-\u3096\u309b-\u309f\u30a1-\u30fa\u30fc-\u30ff\u3105-\u312f\u3131-\u318e\u31a0-\u31ba\u31f0-\u31ff\u3400-\u4db5\u4e00-\u9fef\ua000-\ua48c\ua4d0-\ua4fd\ua500-\ua60c\ua610-\ua61f\ua62a-\ua62b\ua640-\ua66e\ua67f-\ua69d\ua6a0-\ua6ef\ua717-\ua71f\ua722-\ua788\ua78b-\ua7bf\ua7c2-\ua7c6\ua7f7-\ua801\ua803-\ua805\ua807-\ua80a\ua80c-\ua822\ua840-\ua873\ua882-\ua8b3\ua8f2-\ua8f7\ua8fb\ua8fd-\ua8fe\ua90a-\ua925\ua930-\ua946\ua960-\ua97c\ua984-\ua9b2\ua9cf\ua9e0-\ua9e4\ua9e6-\ua9ef\ua9fa-\ua9fe\uaa00-\uaa28\uaa40-\uaa42\uaa44-\uaa4b\uaa60-\uaa76\uaa7a\uaa7e-\uaaaf\uaab1\uaab5-\uaab6\uaab9-\uaabd\uaac0\uaac2\uaadb-\uaadd\uaae0-\uaaea\uaaf2-\uaaf4\uab01-\uab06\uab09-\uab0e\uab11-\uab16\uab20-\uab26\uab28-\uab2e\uab30-\uab5a\uab5c-\uab67\uab70-\uabe2\uac00-\ud7a3\ud7b0-\ud7c6\ud7cb-\ud7fb\uf900-\ufa6d\ufa70-\ufad9\ufb00-\ufb06\ufb13-\ufb17\ufb1d\ufb1f-\ufb28\ufb2a-\ufb36\ufb38-\ufb3c\ufb3e\ufb40-\ufb41\ufb43-\ufb44\ufb46-\ufbb1\ufbd3-\ufd3d\ufd50-\ufd8f\ufd92-\ufdc7\ufdf0-\ufdfb\ufe70-\ufe74\ufe76-\ufefc\uff21-\uff3a\uff41-\uff5a\uff66-\uffbe\uffc2-\uffc7\uffca-\uffcf\uffd2-\uffd7\uffda-\uffdc]|\ud800[\udc00-\udc0b\udc0d-\udc26\udc28-\udc3a\udc3c-\udc3d\udc3f-\udc4d\udc50-\udc5d\udc80-\udcfa\udd40-\udd74\ude80-\ude9c\udea0-\uded0\udf00-\udf1f\udf2d-\udf4a\udf50-\udf75\udf80-\udf9d\udfa0-\udfc3\udfc8-\udfcf\udfd1-\udfd5]|\ud801[\udc00-\udc9d\udcb0-\udcd3\udcd8-\udcfb\udd00-\udd27\udd30-\udd63\ude00-\udf36\udf40-\udf55\udf60-\udf67]|\ud802[\udc00-\udc05\udc08\udc0a-\udc35\udc37-\udc38\udc3c\udc3f-\udc55\udc60-\udc76\udc80-\udc9e\udce0-\udcf2\udcf4-\udcf5\udd00-\udd15\udd20-\udd39\udd80-\uddb7\uddbe-\uddbf\ude00\ude10-\ude13\ude15-\ude17\ude19-\ude35\ude60-\ude7c\ude80-\ude9c\udec0-\udec7\udec9-\udee4\udf00-\udf35\udf40-\udf55\udf60-\udf72\udf80-\udf91]|\ud803[\udc00-\udc48\udc80-\udcb2\udcc0-\udcf2\udd00-\udd23\udf00-\udf1c\udf27\udf30-\udf45\udfe0-\udff6]|\ud804[\udc03-\udc37\udc83-\udcaf\udcd0-\udce8\udd03-\udd26\udd44\udd50-\udd72\udd76\udd83-\uddb2\uddc1-\uddc4\uddda\udddc\ude00-\ude11\ude13-\ude2b\ude80-\ude86\ude88\ude8a-\ude8d\ude8f-\ude9d\ude9f-\udea8\udeb0-\udede\udf05-\udf0c\udf0f-\udf10\udf13-\udf28\udf2a-\udf30\udf32-\udf33\udf35-\udf39\udf3d\udf50\udf5d-\udf61]|\ud805[\udc00-\udc34\udc47-\udc4a\udc5f\udc80-\udcaf\udcc4-\udcc5\udcc7\udd80-\uddae\uddd8-\udddb\ude00-\ude2f\ude44\ude80-\udeaa\udeb8\udf00-\udf1a]|\ud806[\udc00-\udc2b\udca0-\udcdf\udcff\udda0-\udda7\uddaa-\uddd0\udde1\udde3\ude00\ude0b-\ude32\ude3a\ude50\ude5c-\ude89\ude9d\udec0-\udef8]|\ud807[\udc00-\udc08\udc0a-\udc2e\udc40\udc72-\udc8f\udd00-\udd06\udd08-\udd09\udd0b-\udd30\udd46\udd60-\udd65\udd67-\udd68\udd6a-\udd89\udd98\udee0-\udef2]|\ud808[\udc00-\udf99]|\ud809[\udc00-\udc6e\udc80-\udd43]|\ud80c[\udc00-\udfff]|\ud80d[\udc00-\udc2e]|\ud811[\udc00-\ude46]|\ud81a[\udc00-\ude38\ude40-\ude5e\uded0-\udeed\udf00-\udf2f\udf40-\udf43\udf63-\udf77\udf7d-\udf8f]|\ud81b[\ude40-\ude7f\udf00-\udf4a\udf50\udf93-\udf9f\udfe0-\udfe1\udfe3]|\ud81c[\udc00-\udfff]|\ud81d[\udc00-\udfff]|\ud81e[\udc00-\udfff]|\ud81f[\udc00-\udfff]|\ud820[\udc00-\udfff]|\ud821[\udc00-\udff7]|\ud822[\udc00-\udef2]|\ud82c[\udc00-\udd1e\udd50-\udd52\udd64-\udd67\udd70-\udefb]|\ud82f[\udc00-\udc6a\udc70-\udc7c\udc80-\udc88\udc90-\udc99]|\ud835[\udc00-\udc54\udc56-\udc9c\udc9e-\udc9f\udca2\udca5-\udca6\udca9-\udcac\udcae-\udcb9\udcbb\udcbd-\udcc3\udcc5-\udd05\udd07-\udd0a\udd0d-\udd14\udd16-\udd1c\udd1e-\udd39\udd3b-\udd3e\udd40-\udd44\udd46\udd4a-\udd50\udd52-\udea5\udea8-\udec0\udec2-\udeda\udedc-\udefa\udefc-\udf14\udf16-\udf34\udf36-\udf4e\udf50-\udf6e\udf70-\udf88\udf8a-\udfa8\udfaa-\udfc2\udfc4-\udfcb]|\ud838[\udd00-\udd2c\udd37-\udd3d\udd4e\udec0-\udeeb]|\ud83a[\udc00-\udcc4\udd00-\udd43\udd4b]|\ud83b[\ude00-\ude03\ude05-\ude1f\ude21-\ude22\ude24\ude27\ude29-\ude32\ude34-\ude37\ude39\ude3b\ude42\ude47\ude49\ude4b\ude4d-\ude4f\ude51-\ude52\ude54\ude57\ude59\ude5b\ude5d\ude5f\ude61-\ude62\ude64\ude67-\ude6a\ude6c-\ude72\ude74-\ude77\ude79-\ude7c\ude7e\ude80-\ude89\ude8b-\ude9b\udea1-\udea3\udea5-\udea9\udeab-\udebb]|\ud840[\udc00-\udfff]|\ud841[\udc00-\udfff]|\ud842[\udc00-\udfff]|\ud843[\udc00-\udfff]|\ud844[\udc00-\udfff]|\ud845[\udc00-\udfff]|\ud846[\udc00-\udfff]|\ud847[\udc00-\udfff]|\ud848[\udc00-\udfff]|\ud849[\udc00-\udfff]|\ud84a[\udc00-\udfff]|\ud84b[\udc00-\udfff]|\ud84c[\udc00-\udfff]|\ud84d[\udc00-\udfff]|\ud84e[\udc00-\udfff]|\ud84f[\udc00-\udfff]|\ud850[\udc00-\udfff]|\ud851[\udc00-\udfff]|\ud852[\udc00-\udfff]|\ud853[\udc00-\udfff]|\ud854[\udc00-\udfff]|\ud855[\udc00-\udfff]|\ud856[\udc00-\udfff]|\ud857[\udc00-\udfff]|\ud858[\udc00-\udfff]|\ud859[\udc00-\udfff]|\ud85a[\udc00-\udfff]|\ud85b[\udc00-\udfff]|\ud85c[\udc00-\udfff]|\ud85d[\udc00-\udfff]|\ud85e[\udc00-\udfff]|\ud85f[\udc00-\udfff]|\ud860[\udc00-\udfff]|\ud861[\udc00-\udfff]|\ud862[\udc00-\udfff]|\ud863[\udc00-\udfff]|\ud864[\udc00-\udfff]|\ud865[\udc00-\udfff]|\ud866[\udc00-\udfff]|\ud867[\udc00-\udfff]|\ud868[\udc00-\udfff]|\ud869[\udc00-\uded6\udf00-\udfff]|\ud86a[\udc00-\udfff]|\ud86b[\udc00-\udfff]|\ud86c[\udc00-\udfff]|\ud86d[\udc00-\udf34\udf40-\udfff]|\ud86e[\udc00-\udc1d\udc20-\udfff]|\ud86f[\udc00-\udfff]|\ud870[\udc00-\udfff]|\ud871[\udc00-\udfff]|\ud872[\udc00-\udfff]|\ud873[\udc00-\udea1\udeb0-\udfff]|\ud874[\udc00-\udfff]|\ud875[\udc00-\udfff]|\ud876[\udc00-\udfff]|\ud877[\udc00-\udfff]|\ud878[\udc00-\udfff]|\ud879[\udc00-\udfff]|\ud87a[\udc00-\udfe0]|\ud87e[\udc00-\ude1d])|[$_]|(\\u[0-9a-fA-F]{4}|\\u\{[0-9a-fA-F]{1,}\}))(([\u0030-\u0039\u0041-\u005a\u005f\u0061-\u007a\u00aa\u00b5\u00b7\u00ba\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u02c1\u02c6-\u02d1\u02e0-\u02e4\u02ec\u02ee\u0300-\u0374\u0376-\u0377\u037a-\u037d\u037f\u0386-\u038a\u038c\u038e-\u03a1\u03a3-\u03f5\u03f7-\u0481\u0483-\u0487\u048a-\u052f\u0531-\u0556\u0559\u0560-\u0588\u0591-\u05bd\u05bf\u05c1-\u05c2\u05c4-\u05c5\u05c7\u05d0-\u05ea\u05ef-\u05f2\u0610-\u061a\u0620-\u0669\u066e-\u06d3\u06d5-\u06dc\u06df-\u06e8\u06ea-\u06fc\u06ff\u0710-\u074a\u074d-\u07b1\u07c0-\u07f5\u07fa\u07fd\u0800-\u082d\u0840-\u085b\u0860-\u086a\u08a0-\u08b4\u08b6-\u08bd\u08d3-\u08e1\u08e3-\u0963\u0966-\u096f\u0971-\u0983\u0985-\u098c\u098f-\u0990\u0993-\u09a8\u09aa-\u09b0\u09b2\u09b6-\u09b9\u09bc-\u09c4\u09c7-\u09c8\u09cb-\u09ce\u09d7\u09dc-\u09dd\u09df-\u09e3\u09e6-\u09f1\u09fc\u09fe\u0a01-\u0a03\u0a05-\u0a0a\u0a0f-\u0a10\u0a13-\u0a28\u0a2a-\u0a30\u0a32-\u0a33\u0a35-\u0a36\u0a38-\u0a39\u0a3c\u0a3e-\u0a42\u0a47-\u0a48\u0a4b-\u0a4d\u0a51\u0a59-\u0a5c\u0a5e\u0a66-\u0a75\u0a81-\u0a83\u0a85-\u0a8d\u0a8f-\u0a91\u0a93-\u0aa8\u0aaa-\u0ab0\u0ab2-\u0ab3\u0ab5-\u0ab9\u0abc-\u0ac5\u0ac7-\u0ac9\u0acb-\u0acd\u0ad0\u0ae0-\u0ae3\u0ae6-\u0aef\u0af9-\u0aff\u0b01-\u0b03\u0b05-\u0b0c\u0b0f-\u0b10\u0b13-\u0b28\u0b2a-\u0b30\u0b32-\u0b33\u0b35-\u0b39\u0b3c-\u0b44\u0b47-\u0b48\u0b4b-\u0b4d\u0b56-\u0b57\u0b5c-\u0b5d\u0b5f-\u0b63\u0b66-\u0b6f\u0b71\u0b82-\u0b83\u0b85-\u0b8a\u0b8e-\u0b90\u0b92-\u0b95\u0b99-\u0b9a\u0b9c\u0b9e-\u0b9f\u0ba3-\u0ba4\u0ba8-\u0baa\u0bae-\u0bb9\u0bbe-\u0bc2\u0bc6-\u0bc8\u0bca-\u0bcd\u0bd0\u0bd7\u0be6-\u0bef\u0c00-\u0c0c\u0c0e-\u0c10\u0c12-\u0c28\u0c2a-\u0c39\u0c3d-\u0c44\u0c46-\u0c48\u0c4a-\u0c4d\u0c55-\u0c56\u0c58-\u0c5a\u0c60-\u0c63\u0c66-\u0c6f\u0c80-\u0c83\u0c85-\u0c8c\u0c8e-\u0c90\u0c92-\u0ca8\u0caa-\u0cb3\u0cb5-\u0cb9\u0cbc-\u0cc4\u0cc6-\u0cc8\u0cca-\u0ccd\u0cd5-\u0cd6\u0cde\u0ce0-\u0ce3\u0ce6-\u0cef\u0cf1-\u0cf2\u0d00-\u0d03\u0d05-\u0d0c\u0d0e-\u0d10\u0d12-\u0d44\u0d46-\u0d48\u0d4a-\u0d4e\u0d54-\u0d57\u0d5f-\u0d63\u0d66-\u0d6f\u0d7a-\u0d7f\u0d82-\u0d83\u0d85-\u0d96\u0d9a-\u0db1\u0db3-\u0dbb\u0dbd\u0dc0-\u0dc6\u0dca\u0dcf-\u0dd4\u0dd6\u0dd8-\u0ddf\u0de6-\u0def\u0df2-\u0df3\u0e01-\u0e3a\u0e40-\u0e4e\u0e50-\u0e59\u0e81-\u0e82\u0e84\u0e86-\u0e8a\u0e8c-\u0ea3\u0ea5\u0ea7-\u0ebd\u0ec0-\u0ec4\u0ec6\u0ec8-\u0ecd\u0ed0-\u0ed9\u0edc-\u0edf\u0f00\u0f18-\u0f19\u0f20-\u0f29\u0f35\u0f37\u0f39\u0f3e-\u0f47\u0f49-\u0f6c\u0f71-\u0f84\u0f86-\u0f97\u0f99-\u0fbc\u0fc6\u1000-\u1049\u1050-\u109d\u10a0-\u10c5\u10c7\u10cd\u10d0-\u10fa\u10fc-\u1248\u124a-\u124d\u1250-\u1256\u1258\u125a-\u125d\u1260-\u1288\u128a-\u128d\u1290-\u12b0\u12b2-\u12b5\u12b8-\u12be\u12c0\u12c2-\u12c5\u12c8-\u12d6\u12d8-\u1310\u1312-\u1315\u1318-\u135a\u135d-\u135f\u1369-\u1371\u1380-\u138f\u13a0-\u13f5\u13f8-\u13fd\u1401-\u166c\u166f-\u167f\u1681-\u169a\u16a0-\u16ea\u16ee-\u16f8\u1700-\u170c\u170e-\u1714\u1720-\u1734\u1740-\u1753\u1760-\u176c\u176e-\u1770\u1772-\u1773\u1780-\u17d3\u17d7\u17dc-\u17dd\u17e0-\u17e9\u180b-\u180d\u1810-\u1819\u1820-\u1878\u1880-\u18aa\u18b0-\u18f5\u1900-\u191e\u1920-\u192b\u1930-\u193b\u1946-\u196d\u1970-\u1974\u1980-\u19ab\u19b0-\u19c9\u19d0-\u19da\u1a00-\u1a1b\u1a20-\u1a5e\u1a60-\u1a7c\u1a7f-\u1a89\u1a90-\u1a99\u1aa7\u1ab0-\u1abd\u1b00-\u1b4b\u1b50-\u1b59\u1b6b-\u1b73\u1b80-\u1bf3\u1c00-\u1c37\u1c40-\u1c49\u1c4d-\u1c7d\u1c80-\u1c88\u1c90-\u1cba\u1cbd-\u1cbf\u1cd0-\u1cd2\u1cd4-\u1cfa\u1d00-\u1df9\u1dfb-\u1f15\u1f18-\u1f1d\u1f20-\u1f45\u1f48-\u1f4d\u1f50-\u1f57\u1f59\u1f5b\u1f5d\u1f5f-\u1f7d\u1f80-\u1fb4\u1fb6-\u1fbc\u1fbe\u1fc2-\u1fc4\u1fc6-\u1fcc\u1fd0-\u1fd3\u1fd6-\u1fdb\u1fe0-\u1fec\u1ff2-\u1ff4\u1ff6-\u1ffc\u203f-\u2040\u2054\u2071\u207f\u2090-\u209c\u20d0-\u20dc\u20e1\u20e5-\u20f0\u2102\u2107\u210a-\u2113\u2115\u2118-\u211d\u2124\u2126\u2128\u212a-\u2139\u213c-\u213f\u2145-\u2149\u214e\u2160-\u2188\u2c00-\u2c2e\u2c30-\u2c5e\u2c60-\u2ce4\u2ceb-\u2cf3\u2d00-\u2d25\u2d27\u2d2d\u2d30-\u2d67\u2d6f\u2d7f-\u2d96\u2da0-\u2da6\u2da8-\u2dae\u2db0-\u2db6\u2db8-\u2dbe\u2dc0-\u2dc6\u2dc8-\u2dce\u2dd0-\u2dd6\u2dd8-\u2dde\u2de0-\u2dff\u3005-\u3007\u3021-\u302f\u3031-\u3035\u3038-\u303c\u3041-\u3096\u3099-\u309f\u30a1-\u30fa\u30fc-\u30ff\u3105-\u312f\u3131-\u318e\u31a0-\u31ba\u31f0-\u31ff\u3400-\u4db5\u4e00-\u9fef\ua000-\ua48c\ua4d0-\ua4fd\ua500-\ua60c\ua610-\ua62b\ua640-\ua66f\ua674-\ua67d\ua67f-\ua6f1\ua717-\ua71f\ua722-\ua788\ua78b-\ua7bf\ua7c2-\ua7c6\ua7f7-\ua827\ua840-\ua873\ua880-\ua8c5\ua8d0-\ua8d9\ua8e0-\ua8f7\ua8fb\ua8fd-\ua92d\ua930-\ua953\ua960-\ua97c\ua980-\ua9c0\ua9cf-\ua9d9\ua9e0-\ua9fe\uaa00-\uaa36\uaa40-\uaa4d\uaa50-\uaa59\uaa60-\uaa76\uaa7a-\uaac2\uaadb-\uaadd\uaae0-\uaaef\uaaf2-\uaaf6\uab01-\uab06\uab09-\uab0e\uab11-\uab16\uab20-\uab26\uab28-\uab2e\uab30-\uab5a\uab5c-\uab67\uab70-\uabea\uabec-\uabed\uabf0-\uabf9\uac00-\ud7a3\ud7b0-\ud7c6\ud7cb-\ud7fb\uf900-\ufa6d\ufa70-\ufad9\ufb00-\ufb06\ufb13-\ufb17\ufb1d-\ufb28\ufb2a-\ufb36\ufb38-\ufb3c\ufb3e\ufb40-\ufb41\ufb43-\ufb44\ufb46-\ufbb1\ufbd3-\ufd3d\ufd50-\ufd8f\ufd92-\ufdc7\ufdf0-\ufdfb\ufe00-\ufe0f\ufe20-\ufe2f\ufe33-\ufe34\ufe4d-\ufe4f\ufe70-\ufe74\ufe76-\ufefc\uff10-\uff19\uff21-\uff3a\uff3f\uff41-\uff5a\uff66-\uffbe\uffc2-\uffc7\uffca-\uffcf\uffd2-\uffd7\uffda-\uffdc]|\ud800[\udc00-\udc0b\udc0d-\udc26\udc28-\udc3a\udc3c-\udc3d\udc3f-\udc4d\udc50-\udc5d\udc80-\udcfa\udd40-\udd74\uddfd\ude80-\ude9c\udea0-\uded0\udee0\udf00-\udf1f\udf2d-\udf4a\udf50-\udf7a\udf80-\udf9d\udfa0-\udfc3\udfc8-\udfcf\udfd1-\udfd5]|\ud801[\udc00-\udc9d\udca0-\udca9\udcb0-\udcd3\udcd8-\udcfb\udd00-\udd27\udd30-\udd63\ude00-\udf36\udf40-\udf55\udf60-\udf67]|\ud802[\udc00-\udc05\udc08\udc0a-\udc35\udc37-\udc38\udc3c\udc3f-\udc55\udc60-\udc76\udc80-\udc9e\udce0-\udcf2\udcf4-\udcf5\udd00-\udd15\udd20-\udd39\udd80-\uddb7\uddbe-\uddbf\ude00-\ude03\ude05-\ude06\ude0c-\ude13\ude15-\ude17\ude19-\ude35\ude38-\ude3a\ude3f\ude60-\ude7c\ude80-\ude9c\udec0-\udec7\udec9-\udee6\udf00-\udf35\udf40-\udf55\udf60-\udf72\udf80-\udf91]|\ud803[\udc00-\udc48\udc80-\udcb2\udcc0-\udcf2\udd00-\udd27\udd30-\udd39\udf00-\udf1c\udf27\udf30-\udf50\udfe0-\udff6]|\ud804[\udc00-\udc46\udc66-\udc6f\udc7f-\udcba\udcd0-\udce8\udcf0-\udcf9\udd00-\udd34\udd36-\udd3f\udd44-\udd46\udd50-\udd73\udd76\udd80-\uddc4\uddc9-\uddcc\uddd0-\uddda\udddc\ude00-\ude11\ude13-\ude37\ude3e\ude80-\ude86\ude88\ude8a-\ude8d\ude8f-\ude9d\ude9f-\udea8\udeb0-\udeea\udef0-\udef9\udf00-\udf03\udf05-\udf0c\udf0f-\udf10\udf13-\udf28\udf2a-\udf30\udf32-\udf33\udf35-\udf39\udf3b-\udf44\udf47-\udf48\udf4b-\udf4d\udf50\udf57\udf5d-\udf63\udf66-\udf6c\udf70-\udf74]|\ud805[\udc00-\udc4a\udc50-\udc59\udc5e-\udc5f\udc80-\udcc5\udcc7\udcd0-\udcd9\udd80-\uddb5\uddb8-\uddc0\uddd8-\udddd\ude00-\ude40\ude44\ude50-\ude59\ude80-\udeb8\udec0-\udec9\udf00-\udf1a\udf1d-\udf2b\udf30-\udf39]|\ud806[\udc00-\udc3a\udca0-\udce9\udcff\udda0-\udda7\uddaa-\uddd7\uddda-\udde1\udde3-\udde4\ude00-\ude3e\ude47\ude50-\ude99\ude9d\udec0-\udef8]|\ud807[\udc00-\udc08\udc0a-\udc36\udc38-\udc40\udc50-\udc59\udc72-\udc8f\udc92-\udca7\udca9-\udcb6\udd00-\udd06\udd08-\udd09\udd0b-\udd36\udd3a\udd3c-\udd3d\udd3f-\udd47\udd50-\udd59\udd60-\udd65\udd67-\udd68\udd6a-\udd8e\udd90-\udd91\udd93-\udd98\udda0-\udda9\udee0-\udef6]|\ud808[\udc00-\udf99]|\ud809[\udc00-\udc6e\udc80-\udd43]|\ud80c[\udc00-\udfff]|\ud80d[\udc00-\udc2e]|\ud811[\udc00-\ude46]|\ud81a[\udc00-\ude38\ude40-\ude5e\ude60-\ude69\uded0-\udeed\udef0-\udef4\udf00-\udf36\udf40-\udf43\udf50-\udf59\udf63-\udf77\udf7d-\udf8f]|\ud81b[\ude40-\ude7f\udf00-\udf4a\udf4f-\udf87\udf8f-\udf9f\udfe0-\udfe1\udfe3]|\ud81c[\udc00-\udfff]|\ud81d[\udc00-\udfff]|\ud81e[\udc00-\udfff]|\ud81f[\udc00-\udfff]|\ud820[\udc00-\udfff]|\ud821[\udc00-\udff7]|\ud822[\udc00-\udef2]|\ud82c[\udc00-\udd1e\udd50-\udd52\udd64-\udd67\udd70-\udefb]|\ud82f[\udc00-\udc6a\udc70-\udc7c\udc80-\udc88\udc90-\udc99\udc9d-\udc9e]|\ud834[\udd65-\udd69\udd6d-\udd72\udd7b-\udd82\udd85-\udd8b\uddaa-\uddad\ude42-\ude44]|\ud835[\udc00-\udc54\udc56-\udc9c\udc9e-\udc9f\udca2\udca5-\udca6\udca9-\udcac\udcae-\udcb9\udcbb\udcbd-\udcc3\udcc5-\udd05\udd07-\udd0a\udd0d-\udd14\udd16-\udd1c\udd1e-\udd39\udd3b-\udd3e\udd40-\udd44\udd46\udd4a-\udd50\udd52-\udea5\udea8-\udec0\udec2-\udeda\udedc-\udefa\udefc-\udf14\udf16-\udf34\udf36-\udf4e\udf50-\udf6e\udf70-\udf88\udf8a-\udfa8\udfaa-\udfc2\udfc4-\udfcb\udfce-\udfff]|\ud836[\ude00-\ude36\ude3b-\ude6c\ude75\ude84\ude9b-\ude9f\udea1-\udeaf]|\ud838[\udc00-\udc06\udc08-\udc18\udc1b-\udc21\udc23-\udc24\udc26-\udc2a\udd00-\udd2c\udd30-\udd3d\udd40-\udd49\udd4e\udec0-\udef9]|\ud83a[\udc00-\udcc4\udcd0-\udcd6\udd00-\udd4b\udd50-\udd59]|\ud83b[\ude00-\ude03\ude05-\ude1f\ude21-\ude22\ude24\ude27\ude29-\ude32\ude34-\ude37\ude39\ude3b\ude42\ude47\ude49\ude4b\ude4d-\ude4f\ude51-\ude52\ude54\ude57\ude59\ude5b\ude5d\ude5f\ude61-\ude62\ude64\ude67-\ude6a\ude6c-\ude72\ude74-\ude77\ude79-\ude7c\ude7e\ude80-\ude89\ude8b-\ude9b\udea1-\udea3\udea5-\udea9\udeab-\udebb]|\ud840[\udc00-\udfff]|\ud841[\udc00-\udfff]|\ud842[\udc00-\udfff]|\ud843[\udc00-\udfff]|\ud844[\udc00-\udfff]|\ud845[\udc00-\udfff]|\ud846[\udc00-\udfff]|\ud847[\udc00-\udfff]|\ud848[\udc00-\udfff]|\ud849[\udc00-\udfff]|\ud84a[\udc00-\udfff]|\ud84b[\udc00-\udfff]|\ud84c[\udc00-\udfff]|\ud84d[\udc00-\udfff]|\ud84e[\udc00-\udfff]|\ud84f[\udc00-\udfff]|\ud850[\udc00-\udfff]|\ud851[\udc00-\udfff]|\ud852[\udc00-\udfff]|\ud853[\udc00-\udfff]|\ud854[\udc00-\udfff]|\ud855[\udc00-\udfff]|\ud856[\udc00-\udfff]|\ud857[\udc00-\udfff]|\ud858[\udc00-\udfff]|\ud859[\udc00-\udfff]|\ud85a[\udc00-\udfff]|\ud85b[\udc00-\udfff]|\ud85c[\udc00-\udfff]|\ud85d[\udc00-\udfff]|\ud85e[\udc00-\udfff]|\ud85f[\udc00-\udfff]|\ud860[\udc00-\udfff]|\ud861[\udc00-\udfff]|\ud862[\udc00-\udfff]|\ud863[\udc00-\udfff]|\ud864[\udc00-\udfff]|\ud865[\udc00-\udfff]|\ud866[\udc00-\udfff]|\ud867[\udc00-\udfff]|\ud868[\udc00-\udfff]|\ud869[\udc00-\uded6\udf00-\udfff]|\ud86a[\udc00-\udfff]|\ud86b[\udc00-\udfff]|\ud86c[\udc00-\udfff]|\ud86d[\udc00-\udf34\udf40-\udfff]|\ud86e[\udc00-\udc1d\udc20-\udfff]|\ud86f[\udc00-\udfff]|\ud870[\udc00-\udfff]|\ud871[\udc00-\udfff]|\ud872[\udc00-\udfff]|\ud873[\udc00-\udea1\udeb0-\udfff]|\ud874[\udc00-\udfff]|\ud875[\udc00-\udfff]|\ud876[\udc00-\udfff]|\ud877[\udc00-\udfff]|\ud878[\udc00-\udfff]|\ud879[\udc00-\udfff]|\ud87a[\udc00-\udfe0]|\ud87e[\udc00-\ude1d]|\udb40[\udd00-\uddef])|[$_]|(\\u[0-9a-fA-F]{4}|\\u\{[0-9a-fA-F]{1,}\})|[\u200c\u200d])*>/, function() {
        var groupName = yytext.slice(3, -1);
        validateUnicodeGroupName(groupName, this.getCurrentState());
        return "NAMED_GROUP_REF";
      }], [/^\\b/, function() {
        return "ESC_b";
      }], [/^\\B/, function() {
        return "ESC_B";
      }], [/^\\c[a-zA-Z]/, function() {
        return "CTRL_CH";
      }], [/^\\0\d{1,2}/, function() {
        return "OCT_CODE";
      }], [/^\\0/, function() {
        return "DEC_CODE";
      }], [/^\\\d{1,3}/, function() {
        return "DEC_CODE";
      }], [/^\\u[dD][89abAB][0-9a-fA-F]{2}\\u[dD][c-fC-F][0-9a-fA-F]{2}/, function() {
        return "U_CODE_SURROGATE";
      }], [/^\\u\{[0-9a-fA-F]{1,}\}/, function() {
        return "U_CODE";
      }], [/^\\u[0-9a-fA-F]{4}/, function() {
        return "U_CODE";
      }], [/^\\[pP]\{\w+(?:=\w+)?\}/, function() {
        return "U_PROP_VALUE_EXP";
      }], [/^\\x[0-9a-fA-F]{2}/, function() {
        return "HEX_CODE";
      }], [/^\\[tnrdDsSwWvf]/, function() {
        return "META_CHAR";
      }], [/^\\\//, function() {
        return "ESC_CHAR";
      }], [/^\\[ #]/, function() {
        return "ESC_CHAR";
      }], [/^\\[\^\$\.\*\+\?\(\)\\\[\]\{\}\|\/]/, function() {
        return "ESC_CHAR";
      }], [/^\\[^*?+\[()\\|]/, function() {
        var s = this.getCurrentState();
        if (s === "u_class" && yytext === "\\-") {
          return "ESC_CHAR";
        } else if (s === "u" || s === "xu" || s === "u_class") {
          throw new SyntaxError("invalid Unicode escape " + yytext);
        }
        return "ESC_CHAR";
      }], [/^\(/, function() {
        return "CHAR";
      }], [/^\)/, function() {
        return "CHAR";
      }], [/^\(\?=/, function() {
        return "POS_LA_ASSERT";
      }], [/^\(\?!/, function() {
        return "NEG_LA_ASSERT";
      }], [/^\(\?<=/, function() {
        return "POS_LB_ASSERT";
      }], [/^\(\?<!/, function() {
        return "NEG_LB_ASSERT";
      }], [/^\(\?:/, function() {
        return "NON_CAPTURE_GROUP";
      }], [/^\(\?<(([\u0041-\u005a\u0061-\u007a\u00aa\u00b5\u00ba\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u02c1\u02c6-\u02d1\u02e0-\u02e4\u02ec\u02ee\u0370-\u0374\u0376-\u0377\u037a-\u037d\u037f\u0386\u0388-\u038a\u038c\u038e-\u03a1\u03a3-\u03f5\u03f7-\u0481\u048a-\u052f\u0531-\u0556\u0559\u0560-\u0588\u05d0-\u05ea\u05ef-\u05f2\u0620-\u064a\u066e-\u066f\u0671-\u06d3\u06d5\u06e5-\u06e6\u06ee-\u06ef\u06fa-\u06fc\u06ff\u0710\u0712-\u072f\u074d-\u07a5\u07b1\u07ca-\u07ea\u07f4-\u07f5\u07fa\u0800-\u0815\u081a\u0824\u0828\u0840-\u0858\u0860-\u086a\u08a0-\u08b4\u08b6-\u08bd\u0904-\u0939\u093d\u0950\u0958-\u0961\u0971-\u0980\u0985-\u098c\u098f-\u0990\u0993-\u09a8\u09aa-\u09b0\u09b2\u09b6-\u09b9\u09bd\u09ce\u09dc-\u09dd\u09df-\u09e1\u09f0-\u09f1\u09fc\u0a05-\u0a0a\u0a0f-\u0a10\u0a13-\u0a28\u0a2a-\u0a30\u0a32-\u0a33\u0a35-\u0a36\u0a38-\u0a39\u0a59-\u0a5c\u0a5e\u0a72-\u0a74\u0a85-\u0a8d\u0a8f-\u0a91\u0a93-\u0aa8\u0aaa-\u0ab0\u0ab2-\u0ab3\u0ab5-\u0ab9\u0abd\u0ad0\u0ae0-\u0ae1\u0af9\u0b05-\u0b0c\u0b0f-\u0b10\u0b13-\u0b28\u0b2a-\u0b30\u0b32-\u0b33\u0b35-\u0b39\u0b3d\u0b5c-\u0b5d\u0b5f-\u0b61\u0b71\u0b83\u0b85-\u0b8a\u0b8e-\u0b90\u0b92-\u0b95\u0b99-\u0b9a\u0b9c\u0b9e-\u0b9f\u0ba3-\u0ba4\u0ba8-\u0baa\u0bae-\u0bb9\u0bd0\u0c05-\u0c0c\u0c0e-\u0c10\u0c12-\u0c28\u0c2a-\u0c39\u0c3d\u0c58-\u0c5a\u0c60-\u0c61\u0c80\u0c85-\u0c8c\u0c8e-\u0c90\u0c92-\u0ca8\u0caa-\u0cb3\u0cb5-\u0cb9\u0cbd\u0cde\u0ce0-\u0ce1\u0cf1-\u0cf2\u0d05-\u0d0c\u0d0e-\u0d10\u0d12-\u0d3a\u0d3d\u0d4e\u0d54-\u0d56\u0d5f-\u0d61\u0d7a-\u0d7f\u0d85-\u0d96\u0d9a-\u0db1\u0db3-\u0dbb\u0dbd\u0dc0-\u0dc6\u0e01-\u0e30\u0e32-\u0e33\u0e40-\u0e46\u0e81-\u0e82\u0e84\u0e86-\u0e8a\u0e8c-\u0ea3\u0ea5\u0ea7-\u0eb0\u0eb2-\u0eb3\u0ebd\u0ec0-\u0ec4\u0ec6\u0edc-\u0edf\u0f00\u0f40-\u0f47\u0f49-\u0f6c\u0f88-\u0f8c\u1000-\u102a\u103f\u1050-\u1055\u105a-\u105d\u1061\u1065-\u1066\u106e-\u1070\u1075-\u1081\u108e\u10a0-\u10c5\u10c7\u10cd\u10d0-\u10fa\u10fc-\u1248\u124a-\u124d\u1250-\u1256\u1258\u125a-\u125d\u1260-\u1288\u128a-\u128d\u1290-\u12b0\u12b2-\u12b5\u12b8-\u12be\u12c0\u12c2-\u12c5\u12c8-\u12d6\u12d8-\u1310\u1312-\u1315\u1318-\u135a\u1380-\u138f\u13a0-\u13f5\u13f8-\u13fd\u1401-\u166c\u166f-\u167f\u1681-\u169a\u16a0-\u16ea\u16ee-\u16f8\u1700-\u170c\u170e-\u1711\u1720-\u1731\u1740-\u1751\u1760-\u176c\u176e-\u1770\u1780-\u17b3\u17d7\u17dc\u1820-\u1878\u1880-\u18a8\u18aa\u18b0-\u18f5\u1900-\u191e\u1950-\u196d\u1970-\u1974\u1980-\u19ab\u19b0-\u19c9\u1a00-\u1a16\u1a20-\u1a54\u1aa7\u1b05-\u1b33\u1b45-\u1b4b\u1b83-\u1ba0\u1bae-\u1baf\u1bba-\u1be5\u1c00-\u1c23\u1c4d-\u1c4f\u1c5a-\u1c7d\u1c80-\u1c88\u1c90-\u1cba\u1cbd-\u1cbf\u1ce9-\u1cec\u1cee-\u1cf3\u1cf5-\u1cf6\u1cfa\u1d00-\u1dbf\u1e00-\u1f15\u1f18-\u1f1d\u1f20-\u1f45\u1f48-\u1f4d\u1f50-\u1f57\u1f59\u1f5b\u1f5d\u1f5f-\u1f7d\u1f80-\u1fb4\u1fb6-\u1fbc\u1fbe\u1fc2-\u1fc4\u1fc6-\u1fcc\u1fd0-\u1fd3\u1fd6-\u1fdb\u1fe0-\u1fec\u1ff2-\u1ff4\u1ff6-\u1ffc\u2071\u207f\u2090-\u209c\u2102\u2107\u210a-\u2113\u2115\u2118-\u211d\u2124\u2126\u2128\u212a-\u2139\u213c-\u213f\u2145-\u2149\u214e\u2160-\u2188\u2c00-\u2c2e\u2c30-\u2c5e\u2c60-\u2ce4\u2ceb-\u2cee\u2cf2-\u2cf3\u2d00-\u2d25\u2d27\u2d2d\u2d30-\u2d67\u2d6f\u2d80-\u2d96\u2da0-\u2da6\u2da8-\u2dae\u2db0-\u2db6\u2db8-\u2dbe\u2dc0-\u2dc6\u2dc8-\u2dce\u2dd0-\u2dd6\u2dd8-\u2dde\u3005-\u3007\u3021-\u3029\u3031-\u3035\u3038-\u303c\u3041-\u3096\u309b-\u309f\u30a1-\u30fa\u30fc-\u30ff\u3105-\u312f\u3131-\u318e\u31a0-\u31ba\u31f0-\u31ff\u3400-\u4db5\u4e00-\u9fef\ua000-\ua48c\ua4d0-\ua4fd\ua500-\ua60c\ua610-\ua61f\ua62a-\ua62b\ua640-\ua66e\ua67f-\ua69d\ua6a0-\ua6ef\ua717-\ua71f\ua722-\ua788\ua78b-\ua7bf\ua7c2-\ua7c6\ua7f7-\ua801\ua803-\ua805\ua807-\ua80a\ua80c-\ua822\ua840-\ua873\ua882-\ua8b3\ua8f2-\ua8f7\ua8fb\ua8fd-\ua8fe\ua90a-\ua925\ua930-\ua946\ua960-\ua97c\ua984-\ua9b2\ua9cf\ua9e0-\ua9e4\ua9e6-\ua9ef\ua9fa-\ua9fe\uaa00-\uaa28\uaa40-\uaa42\uaa44-\uaa4b\uaa60-\uaa76\uaa7a\uaa7e-\uaaaf\uaab1\uaab5-\uaab6\uaab9-\uaabd\uaac0\uaac2\uaadb-\uaadd\uaae0-\uaaea\uaaf2-\uaaf4\uab01-\uab06\uab09-\uab0e\uab11-\uab16\uab20-\uab26\uab28-\uab2e\uab30-\uab5a\uab5c-\uab67\uab70-\uabe2\uac00-\ud7a3\ud7b0-\ud7c6\ud7cb-\ud7fb\uf900-\ufa6d\ufa70-\ufad9\ufb00-\ufb06\ufb13-\ufb17\ufb1d\ufb1f-\ufb28\ufb2a-\ufb36\ufb38-\ufb3c\ufb3e\ufb40-\ufb41\ufb43-\ufb44\ufb46-\ufbb1\ufbd3-\ufd3d\ufd50-\ufd8f\ufd92-\ufdc7\ufdf0-\ufdfb\ufe70-\ufe74\ufe76-\ufefc\uff21-\uff3a\uff41-\uff5a\uff66-\uffbe\uffc2-\uffc7\uffca-\uffcf\uffd2-\uffd7\uffda-\uffdc]|\ud800[\udc00-\udc0b\udc0d-\udc26\udc28-\udc3a\udc3c-\udc3d\udc3f-\udc4d\udc50-\udc5d\udc80-\udcfa\udd40-\udd74\ude80-\ude9c\udea0-\uded0\udf00-\udf1f\udf2d-\udf4a\udf50-\udf75\udf80-\udf9d\udfa0-\udfc3\udfc8-\udfcf\udfd1-\udfd5]|\ud801[\udc00-\udc9d\udcb0-\udcd3\udcd8-\udcfb\udd00-\udd27\udd30-\udd63\ude00-\udf36\udf40-\udf55\udf60-\udf67]|\ud802[\udc00-\udc05\udc08\udc0a-\udc35\udc37-\udc38\udc3c\udc3f-\udc55\udc60-\udc76\udc80-\udc9e\udce0-\udcf2\udcf4-\udcf5\udd00-\udd15\udd20-\udd39\udd80-\uddb7\uddbe-\uddbf\ude00\ude10-\ude13\ude15-\ude17\ude19-\ude35\ude60-\ude7c\ude80-\ude9c\udec0-\udec7\udec9-\udee4\udf00-\udf35\udf40-\udf55\udf60-\udf72\udf80-\udf91]|\ud803[\udc00-\udc48\udc80-\udcb2\udcc0-\udcf2\udd00-\udd23\udf00-\udf1c\udf27\udf30-\udf45\udfe0-\udff6]|\ud804[\udc03-\udc37\udc83-\udcaf\udcd0-\udce8\udd03-\udd26\udd44\udd50-\udd72\udd76\udd83-\uddb2\uddc1-\uddc4\uddda\udddc\ude00-\ude11\ude13-\ude2b\ude80-\ude86\ude88\ude8a-\ude8d\ude8f-\ude9d\ude9f-\udea8\udeb0-\udede\udf05-\udf0c\udf0f-\udf10\udf13-\udf28\udf2a-\udf30\udf32-\udf33\udf35-\udf39\udf3d\udf50\udf5d-\udf61]|\ud805[\udc00-\udc34\udc47-\udc4a\udc5f\udc80-\udcaf\udcc4-\udcc5\udcc7\udd80-\uddae\uddd8-\udddb\ude00-\ude2f\ude44\ude80-\udeaa\udeb8\udf00-\udf1a]|\ud806[\udc00-\udc2b\udca0-\udcdf\udcff\udda0-\udda7\uddaa-\uddd0\udde1\udde3\ude00\ude0b-\ude32\ude3a\ude50\ude5c-\ude89\ude9d\udec0-\udef8]|\ud807[\udc00-\udc08\udc0a-\udc2e\udc40\udc72-\udc8f\udd00-\udd06\udd08-\udd09\udd0b-\udd30\udd46\udd60-\udd65\udd67-\udd68\udd6a-\udd89\udd98\udee0-\udef2]|\ud808[\udc00-\udf99]|\ud809[\udc00-\udc6e\udc80-\udd43]|\ud80c[\udc00-\udfff]|\ud80d[\udc00-\udc2e]|\ud811[\udc00-\ude46]|\ud81a[\udc00-\ude38\ude40-\ude5e\uded0-\udeed\udf00-\udf2f\udf40-\udf43\udf63-\udf77\udf7d-\udf8f]|\ud81b[\ude40-\ude7f\udf00-\udf4a\udf50\udf93-\udf9f\udfe0-\udfe1\udfe3]|\ud81c[\udc00-\udfff]|\ud81d[\udc00-\udfff]|\ud81e[\udc00-\udfff]|\ud81f[\udc00-\udfff]|\ud820[\udc00-\udfff]|\ud821[\udc00-\udff7]|\ud822[\udc00-\udef2]|\ud82c[\udc00-\udd1e\udd50-\udd52\udd64-\udd67\udd70-\udefb]|\ud82f[\udc00-\udc6a\udc70-\udc7c\udc80-\udc88\udc90-\udc99]|\ud835[\udc00-\udc54\udc56-\udc9c\udc9e-\udc9f\udca2\udca5-\udca6\udca9-\udcac\udcae-\udcb9\udcbb\udcbd-\udcc3\udcc5-\udd05\udd07-\udd0a\udd0d-\udd14\udd16-\udd1c\udd1e-\udd39\udd3b-\udd3e\udd40-\udd44\udd46\udd4a-\udd50\udd52-\udea5\udea8-\udec0\udec2-\udeda\udedc-\udefa\udefc-\udf14\udf16-\udf34\udf36-\udf4e\udf50-\udf6e\udf70-\udf88\udf8a-\udfa8\udfaa-\udfc2\udfc4-\udfcb]|\ud838[\udd00-\udd2c\udd37-\udd3d\udd4e\udec0-\udeeb]|\ud83a[\udc00-\udcc4\udd00-\udd43\udd4b]|\ud83b[\ude00-\ude03\ude05-\ude1f\ude21-\ude22\ude24\ude27\ude29-\ude32\ude34-\ude37\ude39\ude3b\ude42\ude47\ude49\ude4b\ude4d-\ude4f\ude51-\ude52\ude54\ude57\ude59\ude5b\ude5d\ude5f\ude61-\ude62\ude64\ude67-\ude6a\ude6c-\ude72\ude74-\ude77\ude79-\ude7c\ude7e\ude80-\ude89\ude8b-\ude9b\udea1-\udea3\udea5-\udea9\udeab-\udebb]|\ud840[\udc00-\udfff]|\ud841[\udc00-\udfff]|\ud842[\udc00-\udfff]|\ud843[\udc00-\udfff]|\ud844[\udc00-\udfff]|\ud845[\udc00-\udfff]|\ud846[\udc00-\udfff]|\ud847[\udc00-\udfff]|\ud848[\udc00-\udfff]|\ud849[\udc00-\udfff]|\ud84a[\udc00-\udfff]|\ud84b[\udc00-\udfff]|\ud84c[\udc00-\udfff]|\ud84d[\udc00-\udfff]|\ud84e[\udc00-\udfff]|\ud84f[\udc00-\udfff]|\ud850[\udc00-\udfff]|\ud851[\udc00-\udfff]|\ud852[\udc00-\udfff]|\ud853[\udc00-\udfff]|\ud854[\udc00-\udfff]|\ud855[\udc00-\udfff]|\ud856[\udc00-\udfff]|\ud857[\udc00-\udfff]|\ud858[\udc00-\udfff]|\ud859[\udc00-\udfff]|\ud85a[\udc00-\udfff]|\ud85b[\udc00-\udfff]|\ud85c[\udc00-\udfff]|\ud85d[\udc00-\udfff]|\ud85e[\udc00-\udfff]|\ud85f[\udc00-\udfff]|\ud860[\udc00-\udfff]|\ud861[\udc00-\udfff]|\ud862[\udc00-\udfff]|\ud863[\udc00-\udfff]|\ud864[\udc00-\udfff]|\ud865[\udc00-\udfff]|\ud866[\udc00-\udfff]|\ud867[\udc00-\udfff]|\ud868[\udc00-\udfff]|\ud869[\udc00-\uded6\udf00-\udfff]|\ud86a[\udc00-\udfff]|\ud86b[\udc00-\udfff]|\ud86c[\udc00-\udfff]|\ud86d[\udc00-\udf34\udf40-\udfff]|\ud86e[\udc00-\udc1d\udc20-\udfff]|\ud86f[\udc00-\udfff]|\ud870[\udc00-\udfff]|\ud871[\udc00-\udfff]|\ud872[\udc00-\udfff]|\ud873[\udc00-\udea1\udeb0-\udfff]|\ud874[\udc00-\udfff]|\ud875[\udc00-\udfff]|\ud876[\udc00-\udfff]|\ud877[\udc00-\udfff]|\ud878[\udc00-\udfff]|\ud879[\udc00-\udfff]|\ud87a[\udc00-\udfe0]|\ud87e[\udc00-\ude1d])|[$_]|(\\u[0-9a-fA-F]{4}|\\u\{[0-9a-fA-F]{1,}\}))(([\u0030-\u0039\u0041-\u005a\u005f\u0061-\u007a\u00aa\u00b5\u00b7\u00ba\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u02c1\u02c6-\u02d1\u02e0-\u02e4\u02ec\u02ee\u0300-\u0374\u0376-\u0377\u037a-\u037d\u037f\u0386-\u038a\u038c\u038e-\u03a1\u03a3-\u03f5\u03f7-\u0481\u0483-\u0487\u048a-\u052f\u0531-\u0556\u0559\u0560-\u0588\u0591-\u05bd\u05bf\u05c1-\u05c2\u05c4-\u05c5\u05c7\u05d0-\u05ea\u05ef-\u05f2\u0610-\u061a\u0620-\u0669\u066e-\u06d3\u06d5-\u06dc\u06df-\u06e8\u06ea-\u06fc\u06ff\u0710-\u074a\u074d-\u07b1\u07c0-\u07f5\u07fa\u07fd\u0800-\u082d\u0840-\u085b\u0860-\u086a\u08a0-\u08b4\u08b6-\u08bd\u08d3-\u08e1\u08e3-\u0963\u0966-\u096f\u0971-\u0983\u0985-\u098c\u098f-\u0990\u0993-\u09a8\u09aa-\u09b0\u09b2\u09b6-\u09b9\u09bc-\u09c4\u09c7-\u09c8\u09cb-\u09ce\u09d7\u09dc-\u09dd\u09df-\u09e3\u09e6-\u09f1\u09fc\u09fe\u0a01-\u0a03\u0a05-\u0a0a\u0a0f-\u0a10\u0a13-\u0a28\u0a2a-\u0a30\u0a32-\u0a33\u0a35-\u0a36\u0a38-\u0a39\u0a3c\u0a3e-\u0a42\u0a47-\u0a48\u0a4b-\u0a4d\u0a51\u0a59-\u0a5c\u0a5e\u0a66-\u0a75\u0a81-\u0a83\u0a85-\u0a8d\u0a8f-\u0a91\u0a93-\u0aa8\u0aaa-\u0ab0\u0ab2-\u0ab3\u0ab5-\u0ab9\u0abc-\u0ac5\u0ac7-\u0ac9\u0acb-\u0acd\u0ad0\u0ae0-\u0ae3\u0ae6-\u0aef\u0af9-\u0aff\u0b01-\u0b03\u0b05-\u0b0c\u0b0f-\u0b10\u0b13-\u0b28\u0b2a-\u0b30\u0b32-\u0b33\u0b35-\u0b39\u0b3c-\u0b44\u0b47-\u0b48\u0b4b-\u0b4d\u0b56-\u0b57\u0b5c-\u0b5d\u0b5f-\u0b63\u0b66-\u0b6f\u0b71\u0b82-\u0b83\u0b85-\u0b8a\u0b8e-\u0b90\u0b92-\u0b95\u0b99-\u0b9a\u0b9c\u0b9e-\u0b9f\u0ba3-\u0ba4\u0ba8-\u0baa\u0bae-\u0bb9\u0bbe-\u0bc2\u0bc6-\u0bc8\u0bca-\u0bcd\u0bd0\u0bd7\u0be6-\u0bef\u0c00-\u0c0c\u0c0e-\u0c10\u0c12-\u0c28\u0c2a-\u0c39\u0c3d-\u0c44\u0c46-\u0c48\u0c4a-\u0c4d\u0c55-\u0c56\u0c58-\u0c5a\u0c60-\u0c63\u0c66-\u0c6f\u0c80-\u0c83\u0c85-\u0c8c\u0c8e-\u0c90\u0c92-\u0ca8\u0caa-\u0cb3\u0cb5-\u0cb9\u0cbc-\u0cc4\u0cc6-\u0cc8\u0cca-\u0ccd\u0cd5-\u0cd6\u0cde\u0ce0-\u0ce3\u0ce6-\u0cef\u0cf1-\u0cf2\u0d00-\u0d03\u0d05-\u0d0c\u0d0e-\u0d10\u0d12-\u0d44\u0d46-\u0d48\u0d4a-\u0d4e\u0d54-\u0d57\u0d5f-\u0d63\u0d66-\u0d6f\u0d7a-\u0d7f\u0d82-\u0d83\u0d85-\u0d96\u0d9a-\u0db1\u0db3-\u0dbb\u0dbd\u0dc0-\u0dc6\u0dca\u0dcf-\u0dd4\u0dd6\u0dd8-\u0ddf\u0de6-\u0def\u0df2-\u0df3\u0e01-\u0e3a\u0e40-\u0e4e\u0e50-\u0e59\u0e81-\u0e82\u0e84\u0e86-\u0e8a\u0e8c-\u0ea3\u0ea5\u0ea7-\u0ebd\u0ec0-\u0ec4\u0ec6\u0ec8-\u0ecd\u0ed0-\u0ed9\u0edc-\u0edf\u0f00\u0f18-\u0f19\u0f20-\u0f29\u0f35\u0f37\u0f39\u0f3e-\u0f47\u0f49-\u0f6c\u0f71-\u0f84\u0f86-\u0f97\u0f99-\u0fbc\u0fc6\u1000-\u1049\u1050-\u109d\u10a0-\u10c5\u10c7\u10cd\u10d0-\u10fa\u10fc-\u1248\u124a-\u124d\u1250-\u1256\u1258\u125a-\u125d\u1260-\u1288\u128a-\u128d\u1290-\u12b0\u12b2-\u12b5\u12b8-\u12be\u12c0\u12c2-\u12c5\u12c8-\u12d6\u12d8-\u1310\u1312-\u1315\u1318-\u135a\u135d-\u135f\u1369-\u1371\u1380-\u138f\u13a0-\u13f5\u13f8-\u13fd\u1401-\u166c\u166f-\u167f\u1681-\u169a\u16a0-\u16ea\u16ee-\u16f8\u1700-\u170c\u170e-\u1714\u1720-\u1734\u1740-\u1753\u1760-\u176c\u176e-\u1770\u1772-\u1773\u1780-\u17d3\u17d7\u17dc-\u17dd\u17e0-\u17e9\u180b-\u180d\u1810-\u1819\u1820-\u1878\u1880-\u18aa\u18b0-\u18f5\u1900-\u191e\u1920-\u192b\u1930-\u193b\u1946-\u196d\u1970-\u1974\u1980-\u19ab\u19b0-\u19c9\u19d0-\u19da\u1a00-\u1a1b\u1a20-\u1a5e\u1a60-\u1a7c\u1a7f-\u1a89\u1a90-\u1a99\u1aa7\u1ab0-\u1abd\u1b00-\u1b4b\u1b50-\u1b59\u1b6b-\u1b73\u1b80-\u1bf3\u1c00-\u1c37\u1c40-\u1c49\u1c4d-\u1c7d\u1c80-\u1c88\u1c90-\u1cba\u1cbd-\u1cbf\u1cd0-\u1cd2\u1cd4-\u1cfa\u1d00-\u1df9\u1dfb-\u1f15\u1f18-\u1f1d\u1f20-\u1f45\u1f48-\u1f4d\u1f50-\u1f57\u1f59\u1f5b\u1f5d\u1f5f-\u1f7d\u1f80-\u1fb4\u1fb6-\u1fbc\u1fbe\u1fc2-\u1fc4\u1fc6-\u1fcc\u1fd0-\u1fd3\u1fd6-\u1fdb\u1fe0-\u1fec\u1ff2-\u1ff4\u1ff6-\u1ffc\u203f-\u2040\u2054\u2071\u207f\u2090-\u209c\u20d0-\u20dc\u20e1\u20e5-\u20f0\u2102\u2107\u210a-\u2113\u2115\u2118-\u211d\u2124\u2126\u2128\u212a-\u2139\u213c-\u213f\u2145-\u2149\u214e\u2160-\u2188\u2c00-\u2c2e\u2c30-\u2c5e\u2c60-\u2ce4\u2ceb-\u2cf3\u2d00-\u2d25\u2d27\u2d2d\u2d30-\u2d67\u2d6f\u2d7f-\u2d96\u2da0-\u2da6\u2da8-\u2dae\u2db0-\u2db6\u2db8-\u2dbe\u2dc0-\u2dc6\u2dc8-\u2dce\u2dd0-\u2dd6\u2dd8-\u2dde\u2de0-\u2dff\u3005-\u3007\u3021-\u302f\u3031-\u3035\u3038-\u303c\u3041-\u3096\u3099-\u309f\u30a1-\u30fa\u30fc-\u30ff\u3105-\u312f\u3131-\u318e\u31a0-\u31ba\u31f0-\u31ff\u3400-\u4db5\u4e00-\u9fef\ua000-\ua48c\ua4d0-\ua4fd\ua500-\ua60c\ua610-\ua62b\ua640-\ua66f\ua674-\ua67d\ua67f-\ua6f1\ua717-\ua71f\ua722-\ua788\ua78b-\ua7bf\ua7c2-\ua7c6\ua7f7-\ua827\ua840-\ua873\ua880-\ua8c5\ua8d0-\ua8d9\ua8e0-\ua8f7\ua8fb\ua8fd-\ua92d\ua930-\ua953\ua960-\ua97c\ua980-\ua9c0\ua9cf-\ua9d9\ua9e0-\ua9fe\uaa00-\uaa36\uaa40-\uaa4d\uaa50-\uaa59\uaa60-\uaa76\uaa7a-\uaac2\uaadb-\uaadd\uaae0-\uaaef\uaaf2-\uaaf6\uab01-\uab06\uab09-\uab0e\uab11-\uab16\uab20-\uab26\uab28-\uab2e\uab30-\uab5a\uab5c-\uab67\uab70-\uabea\uabec-\uabed\uabf0-\uabf9\uac00-\ud7a3\ud7b0-\ud7c6\ud7cb-\ud7fb\uf900-\ufa6d\ufa70-\ufad9\ufb00-\ufb06\ufb13-\ufb17\ufb1d-\ufb28\ufb2a-\ufb36\ufb38-\ufb3c\ufb3e\ufb40-\ufb41\ufb43-\ufb44\ufb46-\ufbb1\ufbd3-\ufd3d\ufd50-\ufd8f\ufd92-\ufdc7\ufdf0-\ufdfb\ufe00-\ufe0f\ufe20-\ufe2f\ufe33-\ufe34\ufe4d-\ufe4f\ufe70-\ufe74\ufe76-\ufefc\uff10-\uff19\uff21-\uff3a\uff3f\uff41-\uff5a\uff66-\uffbe\uffc2-\uffc7\uffca-\uffcf\uffd2-\uffd7\uffda-\uffdc]|\ud800[\udc00-\udc0b\udc0d-\udc26\udc28-\udc3a\udc3c-\udc3d\udc3f-\udc4d\udc50-\udc5d\udc80-\udcfa\udd40-\udd74\uddfd\ude80-\ude9c\udea0-\uded0\udee0\udf00-\udf1f\udf2d-\udf4a\udf50-\udf7a\udf80-\udf9d\udfa0-\udfc3\udfc8-\udfcf\udfd1-\udfd5]|\ud801[\udc00-\udc9d\udca0-\udca9\udcb0-\udcd3\udcd8-\udcfb\udd00-\udd27\udd30-\udd63\ude00-\udf36\udf40-\udf55\udf60-\udf67]|\ud802[\udc00-\udc05\udc08\udc0a-\udc35\udc37-\udc38\udc3c\udc3f-\udc55\udc60-\udc76\udc80-\udc9e\udce0-\udcf2\udcf4-\udcf5\udd00-\udd15\udd20-\udd39\udd80-\uddb7\uddbe-\uddbf\ude00-\ude03\ude05-\ude06\ude0c-\ude13\ude15-\ude17\ude19-\ude35\ude38-\ude3a\ude3f\ude60-\ude7c\ude80-\ude9c\udec0-\udec7\udec9-\udee6\udf00-\udf35\udf40-\udf55\udf60-\udf72\udf80-\udf91]|\ud803[\udc00-\udc48\udc80-\udcb2\udcc0-\udcf2\udd00-\udd27\udd30-\udd39\udf00-\udf1c\udf27\udf30-\udf50\udfe0-\udff6]|\ud804[\udc00-\udc46\udc66-\udc6f\udc7f-\udcba\udcd0-\udce8\udcf0-\udcf9\udd00-\udd34\udd36-\udd3f\udd44-\udd46\udd50-\udd73\udd76\udd80-\uddc4\uddc9-\uddcc\uddd0-\uddda\udddc\ude00-\ude11\ude13-\ude37\ude3e\ude80-\ude86\ude88\ude8a-\ude8d\ude8f-\ude9d\ude9f-\udea8\udeb0-\udeea\udef0-\udef9\udf00-\udf03\udf05-\udf0c\udf0f-\udf10\udf13-\udf28\udf2a-\udf30\udf32-\udf33\udf35-\udf39\udf3b-\udf44\udf47-\udf48\udf4b-\udf4d\udf50\udf57\udf5d-\udf63\udf66-\udf6c\udf70-\udf74]|\ud805[\udc00-\udc4a\udc50-\udc59\udc5e-\udc5f\udc80-\udcc5\udcc7\udcd0-\udcd9\udd80-\uddb5\uddb8-\uddc0\uddd8-\udddd\ude00-\ude40\ude44\ude50-\ude59\ude80-\udeb8\udec0-\udec9\udf00-\udf1a\udf1d-\udf2b\udf30-\udf39]|\ud806[\udc00-\udc3a\udca0-\udce9\udcff\udda0-\udda7\uddaa-\uddd7\uddda-\udde1\udde3-\udde4\ude00-\ude3e\ude47\ude50-\ude99\ude9d\udec0-\udef8]|\ud807[\udc00-\udc08\udc0a-\udc36\udc38-\udc40\udc50-\udc59\udc72-\udc8f\udc92-\udca7\udca9-\udcb6\udd00-\udd06\udd08-\udd09\udd0b-\udd36\udd3a\udd3c-\udd3d\udd3f-\udd47\udd50-\udd59\udd60-\udd65\udd67-\udd68\udd6a-\udd8e\udd90-\udd91\udd93-\udd98\udda0-\udda9\udee0-\udef6]|\ud808[\udc00-\udf99]|\ud809[\udc00-\udc6e\udc80-\udd43]|\ud80c[\udc00-\udfff]|\ud80d[\udc00-\udc2e]|\ud811[\udc00-\ude46]|\ud81a[\udc00-\ude38\ude40-\ude5e\ude60-\ude69\uded0-\udeed\udef0-\udef4\udf00-\udf36\udf40-\udf43\udf50-\udf59\udf63-\udf77\udf7d-\udf8f]|\ud81b[\ude40-\ude7f\udf00-\udf4a\udf4f-\udf87\udf8f-\udf9f\udfe0-\udfe1\udfe3]|\ud81c[\udc00-\udfff]|\ud81d[\udc00-\udfff]|\ud81e[\udc00-\udfff]|\ud81f[\udc00-\udfff]|\ud820[\udc00-\udfff]|\ud821[\udc00-\udff7]|\ud822[\udc00-\udef2]|\ud82c[\udc00-\udd1e\udd50-\udd52\udd64-\udd67\udd70-\udefb]|\ud82f[\udc00-\udc6a\udc70-\udc7c\udc80-\udc88\udc90-\udc99\udc9d-\udc9e]|\ud834[\udd65-\udd69\udd6d-\udd72\udd7b-\udd82\udd85-\udd8b\uddaa-\uddad\ude42-\ude44]|\ud835[\udc00-\udc54\udc56-\udc9c\udc9e-\udc9f\udca2\udca5-\udca6\udca9-\udcac\udcae-\udcb9\udcbb\udcbd-\udcc3\udcc5-\udd05\udd07-\udd0a\udd0d-\udd14\udd16-\udd1c\udd1e-\udd39\udd3b-\udd3e\udd40-\udd44\udd46\udd4a-\udd50\udd52-\udea5\udea8-\udec0\udec2-\udeda\udedc-\udefa\udefc-\udf14\udf16-\udf34\udf36-\udf4e\udf50-\udf6e\udf70-\udf88\udf8a-\udfa8\udfaa-\udfc2\udfc4-\udfcb\udfce-\udfff]|\ud836[\ude00-\ude36\ude3b-\ude6c\ude75\ude84\ude9b-\ude9f\udea1-\udeaf]|\ud838[\udc00-\udc06\udc08-\udc18\udc1b-\udc21\udc23-\udc24\udc26-\udc2a\udd00-\udd2c\udd30-\udd3d\udd40-\udd49\udd4e\udec0-\udef9]|\ud83a[\udc00-\udcc4\udcd0-\udcd6\udd00-\udd4b\udd50-\udd59]|\ud83b[\ude00-\ude03\ude05-\ude1f\ude21-\ude22\ude24\ude27\ude29-\ude32\ude34-\ude37\ude39\ude3b\ude42\ude47\ude49\ude4b\ude4d-\ude4f\ude51-\ude52\ude54\ude57\ude59\ude5b\ude5d\ude5f\ude61-\ude62\ude64\ude67-\ude6a\ude6c-\ude72\ude74-\ude77\ude79-\ude7c\ude7e\ude80-\ude89\ude8b-\ude9b\udea1-\udea3\udea5-\udea9\udeab-\udebb]|\ud840[\udc00-\udfff]|\ud841[\udc00-\udfff]|\ud842[\udc00-\udfff]|\ud843[\udc00-\udfff]|\ud844[\udc00-\udfff]|\ud845[\udc00-\udfff]|\ud846[\udc00-\udfff]|\ud847[\udc00-\udfff]|\ud848[\udc00-\udfff]|\ud849[\udc00-\udfff]|\ud84a[\udc00-\udfff]|\ud84b[\udc00-\udfff]|\ud84c[\udc00-\udfff]|\ud84d[\udc00-\udfff]|\ud84e[\udc00-\udfff]|\ud84f[\udc00-\udfff]|\ud850[\udc00-\udfff]|\ud851[\udc00-\udfff]|\ud852[\udc00-\udfff]|\ud853[\udc00-\udfff]|\ud854[\udc00-\udfff]|\ud855[\udc00-\udfff]|\ud856[\udc00-\udfff]|\ud857[\udc00-\udfff]|\ud858[\udc00-\udfff]|\ud859[\udc00-\udfff]|\ud85a[\udc00-\udfff]|\ud85b[\udc00-\udfff]|\ud85c[\udc00-\udfff]|\ud85d[\udc00-\udfff]|\ud85e[\udc00-\udfff]|\ud85f[\udc00-\udfff]|\ud860[\udc00-\udfff]|\ud861[\udc00-\udfff]|\ud862[\udc00-\udfff]|\ud863[\udc00-\udfff]|\ud864[\udc00-\udfff]|\ud865[\udc00-\udfff]|\ud866[\udc00-\udfff]|\ud867[\udc00-\udfff]|\ud868[\udc00-\udfff]|\ud869[\udc00-\uded6\udf00-\udfff]|\ud86a[\udc00-\udfff]|\ud86b[\udc00-\udfff]|\ud86c[\udc00-\udfff]|\ud86d[\udc00-\udf34\udf40-\udfff]|\ud86e[\udc00-\udc1d\udc20-\udfff]|\ud86f[\udc00-\udfff]|\ud870[\udc00-\udfff]|\ud871[\udc00-\udfff]|\ud872[\udc00-\udfff]|\ud873[\udc00-\udea1\udeb0-\udfff]|\ud874[\udc00-\udfff]|\ud875[\udc00-\udfff]|\ud876[\udc00-\udfff]|\ud877[\udc00-\udfff]|\ud878[\udc00-\udfff]|\ud879[\udc00-\udfff]|\ud87a[\udc00-\udfe0]|\ud87e[\udc00-\ude1d]|\udb40[\udd00-\uddef])|[$_]|(\\u[0-9a-fA-F]{4}|\\u\{[0-9a-fA-F]{1,}\})|[\u200c\u200d])*>/, function() {
        yytext = yytext.slice(3, -1);
        validateUnicodeGroupName(yytext, this.getCurrentState());
        return "NAMED_CAPTURE_GROUP";
      }], [/^\(/, function() {
        return "L_PAREN";
      }], [/^\)/, function() {
        return "R_PAREN";
      }], [/^[*?+[^$]/, function() {
        return "CHAR";
      }], [/^\\\]/, function() {
        return "ESC_CHAR";
      }], [/^\]/, function() {
        this.popState();
        return "R_BRACKET";
      }], [/^\^/, function() {
        return "BOS";
      }], [/^\$/, function() {
        return "EOS";
      }], [/^\*/, function() {
        return "STAR";
      }], [/^\?/, function() {
        return "Q_MARK";
      }], [/^\+/, function() {
        return "PLUS";
      }], [/^\|/, function() {
        return "BAR";
      }], [/^\./, function() {
        return "ANY";
      }], [/^\//, function() {
        return "SLASH";
      }], [/^[^*?+\[()\\|]/, function() {
        return "CHAR";
      }], [/^\[\^/, function() {
        var s = this.getCurrentState();
        this.pushState(s === "u" || s === "xu" ? "u_class" : "class");
        return "NEG_CLASS";
      }], [/^\[/, function() {
        var s = this.getCurrentState();
        this.pushState(s === "u" || s === "xu" ? "u_class" : "class");
        return "L_BRACKET";
      }]];
      var lexRulesByConditions = { "INITIAL": [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 22, 23, 24, 26, 27, 30, 31, 32, 33, 34, 35, 36, 37, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51], "u": [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 27, 30, 31, 32, 33, 34, 35, 36, 37, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51], "xu": [0, 1, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 30, 31, 32, 33, 34, 35, 36, 37, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51], "x": [0, 1, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 22, 23, 24, 26, 27, 30, 31, 32, 33, 34, 35, 36, 37, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51], "u_class": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51], "class": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 22, 23, 24, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51] };
      var EOF_TOKEN = {
        type: EOF,
        value: ""
      };
      tokenizer = {
        initString: function initString(string) {
          this._string = string;
          this._cursor = 0;
          this._states = ["INITIAL"];
          this._tokensQueue = [];
          this._currentLine = 1;
          this._currentColumn = 0;
          this._currentLineBeginOffset = 0;
          this._tokenStartOffset = 0;
          this._tokenEndOffset = 0;
          this._tokenStartLine = 1;
          this._tokenEndLine = 1;
          this._tokenStartColumn = 0;
          this._tokenEndColumn = 0;
          return this;
        },
        /**
         * Returns tokenizer states.
         */
        getStates: function getStates() {
          return this._states;
        },
        getCurrentState: function getCurrentState() {
          return this._states[this._states.length - 1];
        },
        pushState: function pushState(state) {
          this._states.push(state);
        },
        begin: function begin(state) {
          this.pushState(state);
        },
        popState: function popState() {
          if (this._states.length > 1) {
            return this._states.pop();
          }
          return this._states[0];
        },
        getNextToken: function getNextToken() {
          if (this._tokensQueue.length > 0) {
            return this.onToken(this._toToken(this._tokensQueue.shift()));
          }
          if (!this.hasMoreTokens()) {
            return this.onToken(EOF_TOKEN);
          }
          var string = this._string.slice(this._cursor);
          var lexRulesForState = lexRulesByConditions[this.getCurrentState()];
          for (var i = 0; i < lexRulesForState.length; i++) {
            var lexRuleIndex = lexRulesForState[i];
            var lexRule = lexRules[lexRuleIndex];
            var matched = this._match(string, lexRule[0]);
            if (string === "" && matched === "") {
              this._cursor++;
            }
            if (matched !== null) {
              yytext = matched;
              yyleng = yytext.length;
              var token = lexRule[1].call(this);
              if (!token) {
                return this.getNextToken();
              }
              if (Array.isArray(token)) {
                var tokensToQueue = token.slice(1);
                token = token[0];
                if (tokensToQueue.length > 0) {
                  var _tokensQueue;
                  (_tokensQueue = this._tokensQueue).unshift.apply(_tokensQueue, _toConsumableArray(tokensToQueue));
                }
              }
              return this.onToken(this._toToken(token, yytext));
            }
          }
          if (this.isEOF()) {
            this._cursor++;
            return EOF_TOKEN;
          }
          this.throwUnexpectedToken(string[0], this._currentLine, this._currentColumn);
        },
        /**
         * Throws default "Unexpected token" exception, showing the actual
         * line from the source, pointing with the ^ marker to the bad token.
         * In addition, shows `line:column` location.
         */
        throwUnexpectedToken: function throwUnexpectedToken(symbol, line, column) {
          var lineSource = this._string.split("\n")[line - 1];
          var lineData = "";
          if (lineSource) {
            var pad = " ".repeat(column);
            lineData = "\n\n" + lineSource + "\n" + pad + "^\n";
          }
          throw new SyntaxError(lineData + 'Unexpected token: "' + symbol + '" ' + ("at " + line + ":" + column + "."));
        },
        getCursor: function getCursor() {
          return this._cursor;
        },
        getCurrentLine: function getCurrentLine() {
          return this._currentLine;
        },
        getCurrentColumn: function getCurrentColumn() {
          return this._currentColumn;
        },
        _captureLocation: function _captureLocation(matched) {
          var nlRe = /\n/g;
          this._tokenStartOffset = this._cursor;
          this._tokenStartLine = this._currentLine;
          this._tokenStartColumn = this._tokenStartOffset - this._currentLineBeginOffset;
          var nlMatch = void 0;
          while ((nlMatch = nlRe.exec(matched)) !== null) {
            this._currentLine++;
            this._currentLineBeginOffset = this._tokenStartOffset + nlMatch.index + 1;
          }
          this._tokenEndOffset = this._cursor + matched.length;
          this._tokenEndLine = this._currentLine;
          this._tokenEndColumn = this._currentColumn = this._tokenEndOffset - this._currentLineBeginOffset;
        },
        _toToken: function _toToken(tokenType) {
          var yytext2 = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : "";
          return {
            // Basic data.
            type: tokenType,
            value: yytext2,
            // Location data.
            startOffset: this._tokenStartOffset,
            endOffset: this._tokenEndOffset,
            startLine: this._tokenStartLine,
            endLine: this._tokenEndLine,
            startColumn: this._tokenStartColumn,
            endColumn: this._tokenEndColumn
          };
        },
        isEOF: function isEOF() {
          return this._cursor === this._string.length;
        },
        hasMoreTokens: function hasMoreTokens() {
          return this._cursor <= this._string.length;
        },
        _match: function _match(string, regexp) {
          var matched = string.match(regexp);
          if (matched) {
            this._captureLocation(matched[0]);
            this._cursor += matched[0].length;
            return matched[0];
          }
          return null;
        },
        /**
         * Allows analyzing, and transforming token. Default implementation
         * just passes the token through.
         */
        onToken: function onToken(token) {
          return token;
        }
      };
      yy.lexer = tokenizer;
      yy.tokenizer = tokenizer;
      yy.options = {
        captureLocations: true
      };
      var yyparse = {
        /**
         * Sets global parsing options.
         */
        setOptions: function setOptions(options) {
          yy.options = options;
          return this;
        },
        /**
         * Returns parsing options.
         */
        getOptions: function getOptions() {
          return yy.options;
        },
        /**
         * Parses a string.
         */
        parse: function parse3(string, parseOptions) {
          if (!tokenizer) {
            throw new Error("Tokenizer instance wasn't specified.");
          }
          tokenizer.initString(string);
          var globalOptions = yy.options;
          if (parseOptions) {
            yy.options = Object.assign({}, yy.options, parseOptions);
          }
          yyparse.onParseBegin(string, tokenizer, yy.options);
          stack.length = 0;
          stack.push(0);
          var token = tokenizer.getNextToken();
          var shiftedToken = null;
          do {
            if (!token) {
              yy.options = globalOptions;
              unexpectedEndOfInput();
            }
            var state = stack[stack.length - 1];
            var column = tokens[token.type];
            if (!table[state].hasOwnProperty(column)) {
              yy.options = globalOptions;
              unexpectedToken(token);
            }
            var entry = table[state][column];
            if (entry[0] === "s") {
              var _loc2 = null;
              if (yy.options.captureLocations) {
                _loc2 = {
                  startOffset: token.startOffset,
                  endOffset: token.endOffset,
                  startLine: token.startLine,
                  endLine: token.endLine,
                  startColumn: token.startColumn,
                  endColumn: token.endColumn
                };
              }
              shiftedToken = this.onShift(token);
              stack.push({ symbol: tokens[shiftedToken.type], semanticValue: shiftedToken.value, loc: _loc2 }, Number(entry.slice(1)));
              token = tokenizer.getNextToken();
            } else if (entry[0] === "r") {
              var productionNumber = entry.slice(1);
              var production = productions[productionNumber];
              var hasSemanticAction = typeof production[2] === "function";
              var semanticValueArgs = hasSemanticAction ? [] : null;
              var locationArgs = hasSemanticAction && yy.options.captureLocations ? [] : null;
              if (production[1] !== 0) {
                var rhsLength = production[1];
                while (rhsLength-- > 0) {
                  stack.pop();
                  var stackEntry = stack.pop();
                  if (hasSemanticAction) {
                    semanticValueArgs.unshift(stackEntry.semanticValue);
                    if (locationArgs) {
                      locationArgs.unshift(stackEntry.loc);
                    }
                  }
                }
              }
              var reduceStackEntry = { symbol: production[0] };
              if (hasSemanticAction) {
                yytext = shiftedToken ? shiftedToken.value : null;
                yyleng = shiftedToken ? shiftedToken.value.length : null;
                var semanticActionArgs = locationArgs !== null ? semanticValueArgs.concat(locationArgs) : semanticValueArgs;
                production[2].apply(production, _toConsumableArray(semanticActionArgs));
                reduceStackEntry.semanticValue = __;
                if (locationArgs) {
                  reduceStackEntry.loc = __loc;
                }
              }
              var nextState = stack[stack.length - 1];
              var symbolToReduceWith = production[0];
              stack.push(reduceStackEntry, table[nextState][symbolToReduceWith]);
            } else if (entry === "acc") {
              stack.pop();
              var parsed = stack.pop();
              if (stack.length !== 1 || stack[0] !== 0 || tokenizer.hasMoreTokens()) {
                yy.options = globalOptions;
                unexpectedToken(token);
              }
              if (parsed.hasOwnProperty("semanticValue")) {
                yy.options = globalOptions;
                yyparse.onParseEnd(parsed.semanticValue);
                return parsed.semanticValue;
              }
              yyparse.onParseEnd();
              yy.options = globalOptions;
              return true;
            }
          } while (tokenizer.hasMoreTokens() || stack.length > 1);
        },
        setTokenizer: function setTokenizer(customTokenizer) {
          tokenizer = customTokenizer;
          return yyparse;
        },
        getTokenizer: function getTokenizer() {
          return tokenizer;
        },
        onParseBegin: function onParseBegin(string, tokenizer2, options) {
        },
        onParseEnd: function onParseEnd(parsed) {
        },
        /**
         * Allows analyzing, and transforming shifted token. Default implementation
         * just passes the token through.
         */
        onShift: function onShift(token) {
          return token;
        }
      };
      var capturingGroupsCount = 0;
      var namedGroups = {};
      var parsingString = "";
      yyparse.onParseBegin = function(string, lexer) {
        parsingString = string;
        capturingGroupsCount = 0;
        namedGroups = {};
        var lastSlash = string.lastIndexOf("/");
        var flags = string.slice(lastSlash);
        if (flags.includes("x") && flags.includes("u")) {
          lexer.pushState("xu");
        } else {
          if (flags.includes("x")) {
            lexer.pushState("x");
          }
          if (flags.includes("u")) {
            lexer.pushState("u");
          }
        }
      };
      yyparse.onShift = function(token) {
        if (token.type === "L_PAREN" || token.type === "NAMED_CAPTURE_GROUP") {
          token.value = new String(token.value);
          token.value.groupNumber = ++capturingGroupsCount;
        }
        return token;
      };
      function getRange(text) {
        var range = text.match(/\d+/g).map(Number);
        if (Number.isFinite(range[1]) && range[1] < range[0]) {
          throw new SyntaxError("Numbers out of order in " + text + " quantifier");
        }
        return range;
      }
      function checkClassRange(from, to) {
        if (from.kind === "control" || to.kind === "control" || !isNaN(from.codePoint) && !isNaN(to.codePoint) && from.codePoint > to.codePoint) {
          throw new SyntaxError("Range " + from.value + "-" + to.value + " out of order in character class");
        }
      }
      var unicodeProperties = require_parser_unicode_properties();
      function UnicodeProperty(matched, loc2) {
        var negative = matched[1] === "P";
        var separatorIdx = matched.indexOf("=");
        var name = matched.slice(3, separatorIdx !== -1 ? separatorIdx : -1);
        var value = void 0;
        var isShorthand = separatorIdx === -1 && unicodeProperties.isGeneralCategoryValue(name);
        var isBinaryProperty = separatorIdx === -1 && unicodeProperties.isBinaryPropertyName(name);
        if (isShorthand) {
          value = name;
          name = "General_Category";
        } else if (isBinaryProperty) {
          value = name;
        } else {
          if (!unicodeProperties.isValidName(name)) {
            throw new SyntaxError("Invalid unicode property name: " + name + ".");
          }
          value = matched.slice(separatorIdx + 1, -1);
          if (!unicodeProperties.isValidValue(name, value)) {
            throw new SyntaxError("Invalid " + name + " unicode property value: " + value + ".");
          }
        }
        return Node2({
          type: "UnicodeProperty",
          name,
          value,
          negative,
          shorthand: isShorthand,
          binary: isBinaryProperty,
          canonicalName: unicodeProperties.getCanonicalName(name) || name,
          canonicalValue: unicodeProperties.getCanonicalValue(value) || value
        }, loc2);
      }
      function Char(value, kind, loc2) {
        var symbol = void 0;
        var codePoint = void 0;
        switch (kind) {
          case "decimal": {
            codePoint = Number(value.slice(1));
            symbol = String.fromCodePoint(codePoint);
            break;
          }
          case "oct": {
            codePoint = parseInt(value.slice(1), 8);
            symbol = String.fromCodePoint(codePoint);
            break;
          }
          case "hex":
          case "unicode": {
            if (value.lastIndexOf("\\u") > 0) {
              var _value$split$slice = value.split("\\u").slice(1), _value$split$slice2 = _slicedToArray(_value$split$slice, 2), lead = _value$split$slice2[0], trail = _value$split$slice2[1];
              lead = parseInt(lead, 16);
              trail = parseInt(trail, 16);
              codePoint = (lead - 55296) * 1024 + (trail - 56320) + 65536;
              symbol = String.fromCodePoint(codePoint);
            } else {
              var hex = value.slice(2).replace("{", "");
              codePoint = parseInt(hex, 16);
              if (codePoint > 1114111) {
                throw new SyntaxError("Bad character escape sequence: " + value);
              }
              symbol = String.fromCodePoint(codePoint);
            }
            break;
          }
          case "meta": {
            switch (value) {
              case "\\t":
                symbol = "	";
                codePoint = symbol.codePointAt(0);
                break;
              case "\\n":
                symbol = "\n";
                codePoint = symbol.codePointAt(0);
                break;
              case "\\r":
                symbol = "\r";
                codePoint = symbol.codePointAt(0);
                break;
              case "\\v":
                symbol = "\v";
                codePoint = symbol.codePointAt(0);
                break;
              case "\\f":
                symbol = "\f";
                codePoint = symbol.codePointAt(0);
                break;
              case "\\b":
                symbol = "\b";
                codePoint = symbol.codePointAt(0);
              case "\\0":
                symbol = "\0";
                codePoint = 0;
              case ".":
                symbol = ".";
                codePoint = NaN;
                break;
              default:
                codePoint = NaN;
            }
            break;
          }
          case "simple": {
            symbol = value;
            codePoint = symbol.codePointAt(0);
            break;
          }
        }
        return Node2({
          type: "Char",
          value,
          kind,
          symbol,
          codePoint
        }, loc2);
      }
      var validFlags = "gimsuxy";
      function checkFlags(flags) {
        var seen = /* @__PURE__ */ new Set();
        var _iteratorNormalCompletion = true;
        var _didIteratorError = false;
        var _iteratorError = void 0;
        try {
          for (var _iterator = flags[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
            var flag = _step.value;
            if (seen.has(flag) || !validFlags.includes(flag)) {
              throw new SyntaxError("Invalid flags: " + flags);
            }
            seen.add(flag);
          }
        } catch (err) {
          _didIteratorError = true;
          _iteratorError = err;
        } finally {
          try {
            if (!_iteratorNormalCompletion && _iterator.return) {
              _iterator.return();
            }
          } finally {
            if (_didIteratorError) {
              throw _iteratorError;
            }
          }
        }
        return flags.split("").sort().join("");
      }
      function GroupRefOrDecChar(text, textLoc) {
        var reference = Number(text.slice(1));
        if (reference > 0 && reference <= capturingGroupsCount) {
          return Node2({
            type: "Backreference",
            kind: "number",
            number: reference,
            reference
          }, textLoc);
        }
        return Char(text, "decimal", textLoc);
      }
      var uReStart = /^\\u[0-9a-fA-F]{4}/;
      var ucpReStart = /^\\u\{[0-9a-fA-F]{1,}\}/;
      var ucpReAnywhere = /\\u\{[0-9a-fA-F]{1,}\}/;
      function validateUnicodeGroupName(name, state) {
        var isUnicodeName = ucpReAnywhere.test(name);
        var isUnicodeState = state === "u" || state === "xu" || state === "u_class";
        if (isUnicodeName && !isUnicodeState) {
          throw new SyntaxError('invalid group Unicode name "' + name + '", use `u` flag.');
        }
        return name;
      }
      var uidRe = /\\u(?:([dD][89aAbB][0-9a-fA-F]{2})\\u([dD][c-fC-F][0-9a-fA-F]{2})|([dD][89aAbB][0-9a-fA-F]{2})|([dD][c-fC-F][0-9a-fA-F]{2})|([0-9a-ce-fA-CE-F][0-9a-fA-F]{3}|[dD][0-7][0-9a-fA-F]{2})|\{(0*(?:[0-9a-fA-F]{1,5}|10[0-9a-fA-F]{4}))\})/;
      function decodeUnicodeGroupName(name) {
        return name.replace(new RegExp(uidRe, "g"), function(_, leadSurrogate, trailSurrogate, leadSurrogateOnly, trailSurrogateOnly, nonSurrogate, codePoint) {
          if (leadSurrogate) {
            return String.fromCodePoint(parseInt(leadSurrogate, 16), parseInt(trailSurrogate, 16));
          }
          if (leadSurrogateOnly) {
            return String.fromCodePoint(parseInt(leadSurrogateOnly, 16));
          }
          if (trailSurrogateOnly) {
            return String.fromCodePoint(parseInt(trailSurrogateOnly, 16));
          }
          if (nonSurrogate) {
            return String.fromCodePoint(parseInt(nonSurrogate, 16));
          }
          if (codePoint) {
            return String.fromCodePoint(parseInt(codePoint, 16));
          }
          return _;
        });
      }
      function NamedGroupRefOrChars(text, textLoc) {
        var referenceRaw = text.slice(3, -1);
        var reference = decodeUnicodeGroupName(referenceRaw);
        if (namedGroups.hasOwnProperty(reference)) {
          return Node2({
            type: "Backreference",
            kind: "name",
            number: namedGroups[reference],
            reference,
            referenceRaw
          }, textLoc);
        }
        var startOffset = null;
        var startLine = null;
        var endLine = null;
        var startColumn = null;
        if (textLoc) {
          startOffset = textLoc.startOffset;
          startLine = textLoc.startLine;
          endLine = textLoc.endLine;
          startColumn = textLoc.startColumn;
        }
        var charRe = /^[\w$<>]/;
        var loc2 = void 0;
        var chars = [
          // Init to first \k, taking 2 symbols.
          Char(text.slice(1, 2), "simple", startOffset ? {
            startLine,
            endLine,
            startColumn,
            startOffset,
            endOffset: startOffset += 2,
            endColumn: startColumn += 2
          } : null)
        ];
        chars[0].escaped = true;
        text = text.slice(2);
        while (text.length > 0) {
          var matched = null;
          if ((matched = text.match(uReStart)) || (matched = text.match(ucpReStart))) {
            if (startOffset) {
              loc2 = {
                startLine,
                endLine,
                startColumn,
                startOffset,
                endOffset: startOffset += matched[0].length,
                endColumn: startColumn += matched[0].length
              };
            }
            chars.push(Char(matched[0], "unicode", loc2));
            text = text.slice(matched[0].length);
          } else if (matched = text.match(charRe)) {
            if (startOffset) {
              loc2 = {
                startLine,
                endLine,
                startColumn,
                startOffset,
                endOffset: ++startOffset,
                endColumn: ++startColumn
              };
            }
            chars.push(Char(matched[0], "simple", loc2));
            text = text.slice(1);
          }
        }
        return chars;
      }
      function Node2(node, loc2) {
        if (yy.options.captureLocations) {
          node.loc = {
            source: parsingString.slice(loc2.startOffset, loc2.endOffset),
            start: {
              line: loc2.startLine,
              column: loc2.startColumn,
              offset: loc2.startOffset
            },
            end: {
              line: loc2.endLine,
              column: loc2.endColumn,
              offset: loc2.endOffset
            }
          };
        }
        return node;
      }
      function loc(start, end) {
        if (!yy.options.captureLocations) {
          return null;
        }
        return {
          startOffset: start.startOffset,
          endOffset: end.endOffset,
          startLine: start.startLine,
          endLine: end.endLine,
          startColumn: start.startColumn,
          endColumn: end.endColumn
        };
      }
      function unexpectedToken(token) {
        if (token.type === EOF) {
          unexpectedEndOfInput();
        }
        tokenizer.throwUnexpectedToken(token.value, token.startLine, token.startColumn);
      }
      function unexpectedEndOfInput() {
        parseError("Unexpected end of input.");
      }
      function parseError(message2) {
        throw new SyntaxError(message2);
      }
      module.exports = yyparse;
    }
  });

  // node_modules/regexp-tree/dist/parser/index.js
  var require_parser = __commonJS({
    "node_modules/regexp-tree/dist/parser/index.js"(exports, module) {
      "use strict";
      var regexpTreeParser = require_regexp_tree();
      var generatedParseFn = regexpTreeParser.parse.bind(regexpTreeParser);
      regexpTreeParser.parse = function(regexp, options) {
        return generatedParseFn("" + regexp, options);
      };
      regexpTreeParser.setOptions({ captureLocations: false });
      module.exports = regexpTreeParser;
    }
  });

  // node_modules/regexp-tree/dist/traverse/node-path.js
  var require_node_path = __commonJS({
    "node_modules/regexp-tree/dist/traverse/node-path.js"(exports, module) {
      "use strict";
      var _createClass = /* @__PURE__ */ (function() {
        function defineProperties(target, props) {
          for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
          }
        }
        return function(Constructor, protoProps, staticProps) {
          if (protoProps) defineProperties(Constructor.prototype, protoProps);
          if (staticProps) defineProperties(Constructor, staticProps);
          return Constructor;
        };
      })();
      function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
          throw new TypeError("Cannot call a class as a function");
        }
      }
      var DEFAULT_COLLECTION_PROP = "expressions";
      var DEFAULT_SINGLE_PROP = "expression";
      var NodePath = (function() {
        function NodePath2(node) {
          var parentPath = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : null;
          var property = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : null;
          var index = arguments.length > 3 && arguments[3] !== void 0 ? arguments[3] : null;
          _classCallCheck(this, NodePath2);
          this.node = node;
          this.parentPath = parentPath;
          this.parent = parentPath ? parentPath.node : null;
          this.property = property;
          this.index = index;
        }
        _createClass(NodePath2, [{
          key: "_enforceProp",
          value: function _enforceProp(property) {
            if (!this.node.hasOwnProperty(property)) {
              throw new Error("Node of type " + this.node.type + ` doesn't have "` + property + '" collection.');
            }
          }
          /**
           * Sets a node into a children collection or the single child.
           * By default child nodes are supposed to be under `expressions` property.
           * An explicit property can be passed.
           *
           * @param Object node - a node to set into a collection or as single child
           * @param number index - index at which to set
           * @param string property - name of the collection or single property
           */
        }, {
          key: "setChild",
          value: function setChild(node) {
            var index = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : null;
            var property = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : null;
            var childPath = void 0;
            if (index != null) {
              if (!property) {
                property = DEFAULT_COLLECTION_PROP;
              }
              this._enforceProp(property);
              this.node[property][index] = node;
              childPath = NodePath2.getForNode(node, this, property, index);
            } else {
              if (!property) {
                property = DEFAULT_SINGLE_PROP;
              }
              this._enforceProp(property);
              this.node[property] = node;
              childPath = NodePath2.getForNode(node, this, property, null);
            }
            return childPath;
          }
          /**
           * Appends a node to a children collection.
           * By default child nodes are supposed to be under `expressions` property.
           * An explicit property can be passed.
           *
           * @param Object node - a node to set into a collection or as single child
           * @param string property - name of the collection or single property
           */
        }, {
          key: "appendChild",
          value: function appendChild(node) {
            var property = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : null;
            if (!property) {
              property = DEFAULT_COLLECTION_PROP;
            }
            this._enforceProp(property);
            var end = this.node[property].length;
            return this.setChild(node, end, property);
          }
          /**
           * Inserts a node into a collection.
           * By default child nodes are supposed to be under `expressions` property.
           * An explicit property can be passed.
           *
           * @param Object node - a node to insert into a collection
           * @param number index - index at which to insert
           * @param string property - name of the collection property
           */
        }, {
          key: "insertChildAt",
          value: function insertChildAt(node, index) {
            var property = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : DEFAULT_COLLECTION_PROP;
            this._enforceProp(property);
            this.node[property].splice(index, 0, node);
            if (index <= NodePath2.getTraversingIndex()) {
              NodePath2.updateTraversingIndex(1);
            }
            this._rebuildIndex(this.node, property);
          }
          /**
           * Removes a node.
           */
        }, {
          key: "remove",
          value: function remove() {
            if (this.isRemoved()) {
              return;
            }
            NodePath2.registry.delete(this.node);
            this.node = null;
            if (!this.parent) {
              return;
            }
            if (this.index !== null) {
              this.parent[this.property].splice(this.index, 1);
              if (this.index <= NodePath2.getTraversingIndex()) {
                NodePath2.updateTraversingIndex(-1);
              }
              this._rebuildIndex(this.parent, this.property);
              this.index = null;
              this.property = null;
              return;
            }
            delete this.parent[this.property];
            this.property = null;
          }
          /**
           * Rebuilds child nodes index (used on remove/insert).
           */
        }, {
          key: "_rebuildIndex",
          value: function _rebuildIndex(parent, property) {
            var parentPath = NodePath2.getForNode(parent);
            for (var i = 0; i < parent[property].length; i++) {
              var path = NodePath2.getForNode(parent[property][i], parentPath, property, i);
              path.index = i;
            }
          }
          /**
           * Whether the path was removed.
           */
        }, {
          key: "isRemoved",
          value: function isRemoved() {
            return this.node === null;
          }
          /**
           * Replaces a node with the passed one.
           */
        }, {
          key: "replace",
          value: function replace(newNode) {
            NodePath2.registry.delete(this.node);
            this.node = newNode;
            if (!this.parent) {
              return null;
            }
            if (this.index !== null) {
              this.parent[this.property][this.index] = newNode;
            } else {
              this.parent[this.property] = newNode;
            }
            return NodePath2.getForNode(newNode, this.parentPath, this.property, this.index);
          }
          /**
           * Updates a node inline.
           */
        }, {
          key: "update",
          value: function update(nodeProps) {
            Object.assign(this.node, nodeProps);
          }
          /**
           * Returns parent.
           */
        }, {
          key: "getParent",
          value: function getParent() {
            return this.parentPath;
          }
          /**
           * Returns nth child.
           */
        }, {
          key: "getChild",
          value: function getChild() {
            var n = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : 0;
            if (this.node.expressions) {
              return NodePath2.getForNode(this.node.expressions[n], this, DEFAULT_COLLECTION_PROP, n);
            } else if (this.node.expression && n == 0) {
              return NodePath2.getForNode(this.node.expression, this, DEFAULT_SINGLE_PROP);
            }
            return null;
          }
          /**
           * Whether a path node is syntactically equal to the passed one.
           *
           * NOTE: we don't rely on `source` property from the `loc` data
           * (which would be the fastest comparison), since it might be unsync
           * after several modifications. We use here simple `JSON.stringify`
           * excluding the `loc` data.
           *
           * @param NodePath other - path to compare to.
           * @return boolean
           */
        }, {
          key: "hasEqualSource",
          value: function hasEqualSource(path) {
            return JSON.stringify(this.node, jsonSkipLoc) === JSON.stringify(path.node, jsonSkipLoc);
          }
          /**
           * JSON-encodes a node skipping location.
           */
        }, {
          key: "jsonEncode",
          value: function jsonEncode() {
            var _ref = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {}, format2 = _ref.format, useLoc = _ref.useLoc;
            return JSON.stringify(this.node, useLoc ? null : jsonSkipLoc, format2);
          }
          /**
           * Returns previous sibling.
           */
        }, {
          key: "getPreviousSibling",
          value: function getPreviousSibling() {
            if (!this.parent || this.index == null) {
              return null;
            }
            return NodePath2.getForNode(this.parent[this.property][this.index - 1], NodePath2.getForNode(this.parent), this.property, this.index - 1);
          }
          /**
           * Returns next sibling.
           */
        }, {
          key: "getNextSibling",
          value: function getNextSibling() {
            if (!this.parent || this.index == null) {
              return null;
            }
            return NodePath2.getForNode(this.parent[this.property][this.index + 1], NodePath2.getForNode(this.parent), this.property, this.index + 1);
          }
          /**
           * Returns a NodePath instance for a node.
           *
           * The same NodePath can be reused in several places, e.g.
           * a parent node passed for all its children.
           */
        }], [{
          key: "getForNode",
          value: function getForNode(node) {
            var parentPath = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : null;
            var prop = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : null;
            var index = arguments.length > 3 && arguments[3] !== void 0 ? arguments[3] : -1;
            if (!node) {
              return null;
            }
            if (!NodePath2.registry.has(node)) {
              NodePath2.registry.set(node, new NodePath2(node, parentPath, prop, index == -1 ? null : index));
            }
            var path = NodePath2.registry.get(node);
            if (parentPath !== null) {
              path.parentPath = parentPath;
              path.parent = path.parentPath.node;
            }
            if (prop !== null) {
              path.property = prop;
            }
            if (index >= 0) {
              path.index = index;
            }
            return path;
          }
          /**
           * Initializes the NodePath registry. The registry is a map from
           * a node to its NodePath instance.
           */
        }, {
          key: "initRegistry",
          value: function initRegistry() {
            if (!NodePath2.registry) {
              NodePath2.registry = /* @__PURE__ */ new Map();
            }
            NodePath2.registry.clear();
          }
          /**
           * Updates index of a currently traversing collection.
           */
        }, {
          key: "updateTraversingIndex",
          value: function updateTraversingIndex(dx) {
            return NodePath2.traversingIndexStack[NodePath2.traversingIndexStack.length - 1] += dx;
          }
          /**
           * Returns current traversing index.
           */
        }, {
          key: "getTraversingIndex",
          value: function getTraversingIndex() {
            return NodePath2.traversingIndexStack[NodePath2.traversingIndexStack.length - 1];
          }
        }]);
        return NodePath2;
      })();
      NodePath.initRegistry();
      NodePath.traversingIndexStack = [];
      function jsonSkipLoc(prop, value) {
        if (prop === "loc") {
          return void 0;
        }
        return value;
      }
      module.exports = NodePath;
    }
  });

  // node_modules/regexp-tree/dist/traverse/index.js
  var require_traverse = __commonJS({
    "node_modules/regexp-tree/dist/traverse/index.js"(exports, module) {
      "use strict";
      var NodePath = require_node_path();
      function astTraverse(root) {
        var options = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : {};
        var pre = options.pre;
        var post = options.post;
        var skipProperty = options.skipProperty;
        function visit(node, parent, prop, idx) {
          if (!node || typeof node.type !== "string") {
            return;
          }
          var res = void 0;
          if (pre) {
            res = pre(node, parent, prop, idx);
          }
          if (res !== false) {
            if (parent && parent[prop]) {
              if (!isNaN(idx)) {
                node = parent[prop][idx];
              } else {
                node = parent[prop];
              }
            }
            for (var _prop in node) {
              if (node.hasOwnProperty(_prop)) {
                if (skipProperty ? skipProperty(_prop, node) : _prop[0] === "$") {
                  continue;
                }
                var child = node[_prop];
                if (Array.isArray(child)) {
                  var index = 0;
                  NodePath.traversingIndexStack.push(index);
                  while (index < child.length) {
                    visit(child[index], node, _prop, index);
                    index = NodePath.updateTraversingIndex(1);
                  }
                  NodePath.traversingIndexStack.pop();
                } else {
                  visit(child, node, _prop);
                }
              }
            }
          }
          if (post) {
            post(node, parent, prop, idx);
          }
        }
        visit(root, null);
      }
      module.exports = {
        /**
         * Traverses an AST.
         *
         * @param Object ast - an AST node
         *
         * @param Object | Array<Object> handlers:
         *
         *   an object (or an array of objects)
         *
         *   Each such object contains a handler function per node.
         *   In case of an array of handlers, they are applied in order.
         *   A handler may return a transformed node (or a different type).
         *
         *   The per-node function may instead be an object with functions pre and post.
         *   pre is called before visiting the node, post after.
         *   If a handler is a function, it is treated as the pre function, with an empty post.
         *
         * @param Object options:
         *
         *   a config object, specifying traversal options:
         *
         *   `asNodes`: boolean - whether handlers should receives raw AST nodes
         *   (false by default), instead of a `NodePath` wrapper. Note, by default
         *   `NodePath` wrapper provides a set of convenient method to manipulate
         *   a traversing AST, and also has access to all parents list. A raw
         *   nodes traversal should be used in rare cases, when no `NodePath`
         *   features are needed.
         *
         * Special hooks:
         *
         *   - `shouldRun(ast)` - a predicate determining whether the handler
         *                        should be applied.
         *
         * NOTE: Multiple handlers are used as an optimization of applying all of
         * them in one AST traversal pass.
         */
        traverse: function traverse(ast, handlers) {
          var options = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : { asNodes: false };
          if (!Array.isArray(handlers)) {
            handlers = [handlers];
          }
          handlers = handlers.filter(function(handler) {
            if (typeof handler.shouldRun !== "function") {
              return true;
            }
            return handler.shouldRun(ast);
          });
          NodePath.initRegistry();
          handlers.forEach(function(handler) {
            if (typeof handler.init === "function") {
              handler.init(ast);
            }
          });
          function getPathFor(node, parent, prop, index) {
            var parentPath = NodePath.getForNode(parent);
            var nodePath = NodePath.getForNode(node, parentPath, prop, index);
            return nodePath;
          }
          astTraverse(ast, {
            /**
             * Handler on node enter.
             */
            pre: function pre(node, parent, prop, index) {
              var nodePath = void 0;
              if (!options.asNodes) {
                nodePath = getPathFor(node, parent, prop, index);
              }
              var _iteratorNormalCompletion = true;
              var _didIteratorError = false;
              var _iteratorError = void 0;
              try {
                for (var _iterator = handlers[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
                  var handler = _step.value;
                  if (typeof handler["*"] === "function") {
                    if (nodePath) {
                      if (!nodePath.isRemoved()) {
                        var handlerResult = handler["*"](nodePath);
                        if (handlerResult === false) {
                          return false;
                        }
                      }
                    } else {
                      handler["*"](node, parent, prop, index);
                    }
                  }
                  var handlerFuncPre = void 0;
                  if (typeof handler[node.type] === "function") {
                    handlerFuncPre = handler[node.type];
                  } else if (typeof handler[node.type] === "object" && typeof handler[node.type].pre === "function") {
                    handlerFuncPre = handler[node.type].pre;
                  }
                  if (handlerFuncPre) {
                    if (nodePath) {
                      if (!nodePath.isRemoved()) {
                        var _handlerResult = handlerFuncPre.call(handler, nodePath);
                        if (_handlerResult === false) {
                          return false;
                        }
                      }
                    } else {
                      handlerFuncPre.call(handler, node, parent, prop, index);
                    }
                  }
                }
              } catch (err) {
                _didIteratorError = true;
                _iteratorError = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion && _iterator.return) {
                    _iterator.return();
                  }
                } finally {
                  if (_didIteratorError) {
                    throw _iteratorError;
                  }
                }
              }
            },
            // pre func
            /**
             * Handler on node exit.
             */
            post: function post(node, parent, prop, index) {
              if (!node) {
                return;
              }
              var nodePath = void 0;
              if (!options.asNodes) {
                nodePath = getPathFor(node, parent, prop, index);
              }
              var _iteratorNormalCompletion2 = true;
              var _didIteratorError2 = false;
              var _iteratorError2 = void 0;
              try {
                for (var _iterator2 = handlers[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
                  var handler = _step2.value;
                  var handlerFuncPost = void 0;
                  if (typeof handler[node.type] === "object" && typeof handler[node.type].post === "function") {
                    handlerFuncPost = handler[node.type].post;
                  }
                  if (handlerFuncPost) {
                    if (nodePath) {
                      if (!nodePath.isRemoved()) {
                        var handlerResult = handlerFuncPost.call(handler, nodePath);
                        if (handlerResult === false) {
                          return false;
                        }
                      }
                    } else {
                      handlerFuncPost.call(handler, node, parent, prop, index);
                    }
                  }
                }
              } catch (err) {
                _didIteratorError2 = true;
                _iteratorError2 = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion2 && _iterator2.return) {
                    _iterator2.return();
                  }
                } finally {
                  if (_didIteratorError2) {
                    throw _iteratorError2;
                  }
                }
              }
            },
            // post func
            /**
             * Skip locations by default.
             */
            skipProperty: function skipProperty(prop) {
              return prop === "loc";
            }
          });
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/transform/index.js
  var require_transform = __commonJS({
    "node_modules/regexp-tree/dist/transform/index.js"(exports, module) {
      "use strict";
      var _createClass = /* @__PURE__ */ (function() {
        function defineProperties(target, props) {
          for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
          }
        }
        return function(Constructor, protoProps, staticProps) {
          if (protoProps) defineProperties(Constructor.prototype, protoProps);
          if (staticProps) defineProperties(Constructor, staticProps);
          return Constructor;
        };
      })();
      function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
          throw new TypeError("Cannot call a class as a function");
        }
      }
      var generator = require_generator();
      var parser = require_parser();
      var traverse = require_traverse();
      var TransformResult = (function() {
        function TransformResult2(ast) {
          var extra = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : null;
          _classCallCheck(this, TransformResult2);
          this._ast = ast;
          this._source = null;
          this._string = null;
          this._regexp = null;
          this._extra = extra;
        }
        _createClass(TransformResult2, [{
          key: "getAST",
          value: function getAST() {
            return this._ast;
          }
        }, {
          key: "setExtra",
          value: function setExtra(extra) {
            this._extra = extra;
          }
        }, {
          key: "getExtra",
          value: function getExtra() {
            return this._extra;
          }
        }, {
          key: "toRegExp",
          value: function toRegExp() {
            if (!this._regexp) {
              this._regexp = new RegExp(this.getSource(), this._ast.flags);
            }
            return this._regexp;
          }
        }, {
          key: "getSource",
          value: function getSource() {
            if (!this._source) {
              this._source = generator.generate(this._ast.body);
            }
            return this._source;
          }
        }, {
          key: "getFlags",
          value: function getFlags() {
            return this._ast.flags;
          }
        }, {
          key: "toString",
          value: function toString() {
            if (!this._string) {
              this._string = generator.generate(this._ast);
            }
            return this._string;
          }
        }]);
        return TransformResult2;
      })();
      module.exports = {
        /**
         * Expose `TransformResult`.
         */
        TransformResult,
        /**
         * Transforms a regular expression applying a set of
         * transformation handlers.
         *
         * @param string | AST | RegExp:
         *
         *   a regular expression in different representations: a string,
         *   a RegExp object, or an AST.
         *
         * @param Object | Array<Object>:
         *
         *   a handler (or a list of handlers) from `traverse` API.
         *
         * @return TransformResult instance.
         *
         * Example:
         *
         *   transform(/[a-z]/i, {
         *     onChar(path) {
         *       const {node} = path;
         *
         *       if (...) {
         *         path.remove();
         *       }
         *     }
         *   });
         */
        transform: function transform(regexp, handlers) {
          var ast = regexp;
          if (regexp instanceof RegExp) {
            regexp = "" + regexp;
          }
          if (typeof regexp === "string") {
            ast = parser.parse(regexp, {
              captureLocations: true
            });
          }
          traverse.traverse(ast, handlers);
          return new TransformResult(ast);
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/compat-transpiler/index.js
  var require_compat_transpiler = __commonJS({
    "node_modules/regexp-tree/dist/compat-transpiler/index.js"(exports, module) {
      "use strict";
      var compatTransforms = require_transforms();
      var _transform = require_transform();
      module.exports = {
        /**
         * Translates a regexp in new syntax to equivalent regexp in old syntax.
         *
         * @param string|RegExp|AST - regexp
         * @param Array transformsWhitelist - names of the transforms to apply
         */
        transform: function transform(regexp) {
          var transformsWhitelist = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : [];
          var transformToApply = transformsWhitelist.length > 0 ? transformsWhitelist : Object.keys(compatTransforms);
          var result = void 0;
          var extra = {};
          transformToApply.forEach(function(transformName) {
            if (!compatTransforms.hasOwnProperty(transformName)) {
              throw new Error("Unknown compat-transform: " + transformName + ". Available transforms are: " + Object.keys(compatTransforms).join(", "));
            }
            var handler = compatTransforms[transformName];
            result = _transform.transform(regexp, handler);
            regexp = result.getAST();
            if (typeof handler.getExtra === "function") {
              extra[transformName] = handler.getExtra();
            }
          });
          result.setExtra(extra);
          return result;
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/utils/clone.js
  var require_clone = __commonJS({
    "node_modules/regexp-tree/dist/utils/clone.js"(exports, module) {
      "use strict";
      module.exports = function clone(obj) {
        if (obj === null || typeof obj !== "object") {
          return obj;
        }
        var res = void 0;
        if (Array.isArray(obj)) {
          res = [];
        } else {
          res = {};
        }
        for (var i in obj) {
          res[i] = clone(obj[i]);
        }
        return res;
      };
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-surrogate-pair-to-single-unicode-transform.js
  var require_char_surrogate_pair_to_single_unicode_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-surrogate-pair-to-single-unicode-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        shouldRun: function shouldRun(ast) {
          return ast.flags.includes("u");
        },
        Char: function Char(path) {
          var node = path.node;
          if (node.kind !== "unicode" || !node.isSurrogatePair || isNaN(node.codePoint)) {
            return;
          }
          node.value = "\\u{" + node.codePoint.toString(16) + "}";
          delete node.isSurrogatePair;
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-code-to-simple-char-transform.js
  var require_char_code_to_simple_char_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-code-to-simple-char-transform.js"(exports, module) {
      "use strict";
      var UPPER_A_CP = "A".codePointAt(0);
      var UPPER_Z_CP = "Z".codePointAt(0);
      var LOWER_A_CP = "a".codePointAt(0);
      var LOWER_Z_CP = "z".codePointAt(0);
      var DIGIT_0_CP = "0".codePointAt(0);
      var DIGIT_9_CP = "9".codePointAt(0);
      module.exports = {
        Char: function Char(path) {
          var node = path.node, parent = path.parent;
          if (isNaN(node.codePoint) || node.kind === "simple") {
            return;
          }
          if (parent.type === "ClassRange") {
            if (!isSimpleRange(parent)) {
              return;
            }
          }
          if (!isPrintableASCIIChar(node.codePoint)) {
            return;
          }
          var symbol = String.fromCodePoint(node.codePoint);
          var newChar = {
            type: "Char",
            kind: "simple",
            value: symbol,
            symbol,
            codePoint: node.codePoint
          };
          if (needsEscape(symbol, parent.type)) {
            newChar.escaped = true;
          }
          path.replace(newChar);
        }
      };
      function isSimpleRange(classRange) {
        var from = classRange.from, to = classRange.to;
        return from.codePoint >= DIGIT_0_CP && from.codePoint <= DIGIT_9_CP && to.codePoint >= DIGIT_0_CP && to.codePoint <= DIGIT_9_CP || from.codePoint >= UPPER_A_CP && from.codePoint <= UPPER_Z_CP && to.codePoint >= UPPER_A_CP && to.codePoint <= UPPER_Z_CP || from.codePoint >= LOWER_A_CP && from.codePoint <= LOWER_Z_CP && to.codePoint >= LOWER_A_CP && to.codePoint <= LOWER_Z_CP;
      }
      function isPrintableASCIIChar(codePoint) {
        return codePoint >= 32 && codePoint <= 126;
      }
      function needsEscape(symbol, parentType) {
        if (parentType === "ClassRange" || parentType === "CharacterClass") {
          return /[\]\\^-]/.test(symbol);
        }
        return /[*[()+?^$./\\|{}]/.test(symbol);
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-case-insensitive-lowercase-transform.js
  var require_char_case_insensitive_lowercase_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-case-insensitive-lowercase-transform.js"(exports, module) {
      "use strict";
      var UPPER_A_CP = "A".codePointAt(0);
      var UPPER_Z_CP = "Z".codePointAt(0);
      module.exports = {
        _AZClassRanges: null,
        _hasUFlag: false,
        init: function init(ast) {
          this._AZClassRanges = /* @__PURE__ */ new Set();
          this._hasUFlag = ast.flags.includes("u");
        },
        shouldRun: function shouldRun(ast) {
          return ast.flags.includes("i");
        },
        Char: function Char(path) {
          var node = path.node, parent = path.parent;
          if (isNaN(node.codePoint)) {
            return;
          }
          if (!this._hasUFlag && node.codePoint >= 4096) {
            return;
          }
          if (parent.type === "ClassRange") {
            if (!this._AZClassRanges.has(parent) && !isAZClassRange(parent)) {
              return;
            }
            this._AZClassRanges.add(parent);
          }
          var lower = node.symbol.toLowerCase();
          if (lower !== node.symbol) {
            node.value = displaySymbolAsValue(lower, node);
            node.symbol = lower;
            node.codePoint = lower.codePointAt(0);
          }
        }
      };
      function isAZClassRange(classRange) {
        var from = classRange.from, to = classRange.to;
        return from.codePoint >= UPPER_A_CP && from.codePoint <= UPPER_Z_CP && to.codePoint >= UPPER_A_CP && to.codePoint <= UPPER_Z_CP;
      }
      function displaySymbolAsValue(symbol, node) {
        var codePoint = symbol.codePointAt(0);
        if (node.kind === "decimal") {
          return "\\" + codePoint;
        }
        if (node.kind === "oct") {
          return "\\0" + codePoint.toString(8);
        }
        if (node.kind === "hex") {
          return "\\x" + codePoint.toString(16);
        }
        if (node.kind === "unicode") {
          if (node.isSurrogatePair) {
            var _getSurrogatePairFrom = getSurrogatePairFromCodePoint(codePoint), lead = _getSurrogatePairFrom.lead, trail = _getSurrogatePairFrom.trail;
            return "\\u" + "0".repeat(4 - lead.length) + lead + "\\u" + "0".repeat(4 - trail.length) + trail;
          } else if (node.value.includes("{")) {
            return "\\u{" + codePoint.toString(16) + "}";
          } else {
            var code = codePoint.toString(16);
            return "\\u" + "0".repeat(4 - code.length) + code;
          }
        }
        return symbol;
      }
      function getSurrogatePairFromCodePoint(codePoint) {
        var lead = Math.floor((codePoint - 65536) / 1024) + 55296;
        var trail = (codePoint - 65536) % 1024 + 56320;
        return {
          lead: lead.toString(16),
          trail: trail.toString(16)
        };
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-class-remove-duplicates-transform.js
  var require_char_class_remove_duplicates_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-class-remove-duplicates-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        CharacterClass: function CharacterClass(path) {
          var node = path.node;
          var sources = {};
          for (var i = 0; i < node.expressions.length; i++) {
            var childPath = path.getChild(i);
            var source = childPath.jsonEncode();
            if (sources.hasOwnProperty(source)) {
              childPath.remove();
              i--;
            }
            sources[source] = true;
          }
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/transform/utils.js
  var require_utils2 = __commonJS({
    "node_modules/regexp-tree/dist/transform/utils.js"(exports, module) {
      "use strict";
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      function disjunctionToList(node) {
        if (node.type !== "Disjunction") {
          throw new TypeError('Expected "Disjunction" node, got "' + node.type + '"');
        }
        var list = [];
        if (node.left && node.left.type === "Disjunction") {
          list.push.apply(list, _toConsumableArray(disjunctionToList(node.left)).concat([node.right]));
        } else {
          list.push(node.left, node.right);
        }
        return list;
      }
      function listToDisjunction(list) {
        return list.reduce(function(left, right) {
          return {
            type: "Disjunction",
            left,
            right
          };
        });
      }
      function increaseQuantifierByOne(quantifier) {
        if (quantifier.kind === "*") {
          quantifier.kind = "+";
        } else if (quantifier.kind === "+") {
          quantifier.kind = "Range";
          quantifier.from = 2;
          delete quantifier.to;
        } else if (quantifier.kind === "?") {
          quantifier.kind = "Range";
          quantifier.from = 1;
          quantifier.to = 2;
        } else if (quantifier.kind === "Range") {
          quantifier.from += 1;
          if (quantifier.to) {
            quantifier.to += 1;
          }
        }
      }
      module.exports = {
        disjunctionToList,
        listToDisjunction,
        increaseQuantifierByOne
      };
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/quantifiers-merge-transform.js
  var require_quantifiers_merge_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/quantifiers-merge-transform.js"(exports, module) {
      "use strict";
      var _require = require_utils2();
      var increaseQuantifierByOne = _require.increaseQuantifierByOne;
      module.exports = {
        Repetition: function Repetition(path) {
          var node = path.node, parent = path.parent;
          if (parent.type !== "Alternative" || !path.index) {
            return;
          }
          var previousSibling = path.getPreviousSibling();
          if (!previousSibling) {
            return;
          }
          if (previousSibling.node.type === "Repetition") {
            if (!previousSibling.getChild().hasEqualSource(path.getChild())) {
              return;
            }
            var _extractFromTo = extractFromTo(previousSibling.node.quantifier), previousSiblingFrom = _extractFromTo.from, previousSiblingTo = _extractFromTo.to;
            var _extractFromTo2 = extractFromTo(node.quantifier), nodeFrom = _extractFromTo2.from, nodeTo = _extractFromTo2.to;
            if (previousSibling.node.quantifier.greedy !== node.quantifier.greedy && !isGreedyOpenRange(previousSibling.node.quantifier) && !isGreedyOpenRange(node.quantifier)) {
              return;
            }
            node.quantifier.kind = "Range";
            node.quantifier.from = previousSiblingFrom + nodeFrom;
            if (previousSiblingTo && nodeTo) {
              node.quantifier.to = previousSiblingTo + nodeTo;
            } else {
              delete node.quantifier.to;
            }
            if (isGreedyOpenRange(previousSibling.node.quantifier) || isGreedyOpenRange(node.quantifier)) {
              node.quantifier.greedy = true;
            }
            previousSibling.remove();
          } else {
            if (!previousSibling.hasEqualSource(path.getChild())) {
              return;
            }
            increaseQuantifierByOne(node.quantifier);
            previousSibling.remove();
          }
        }
      };
      function isGreedyOpenRange(quantifier) {
        return quantifier.greedy && (quantifier.kind === "+" || quantifier.kind === "*" || quantifier.kind === "Range" && !quantifier.to);
      }
      function extractFromTo(quantifier) {
        var from = void 0, to = void 0;
        if (quantifier.kind === "*") {
          from = 0;
        } else if (quantifier.kind === "+") {
          from = 1;
        } else if (quantifier.kind === "?") {
          from = 0;
          to = 1;
        } else {
          from = quantifier.from;
          if (quantifier.to) {
            to = quantifier.to;
          }
        }
        return { from, to };
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/quantifier-range-to-symbol-transform.js
  var require_quantifier_range_to_symbol_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/quantifier-range-to-symbol-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        Quantifier: function Quantifier(path) {
          var node = path.node;
          if (node.kind !== "Range") {
            return;
          }
          rewriteOpenZero(path);
          rewriteOpenOne(path);
          rewriteExactOne(path);
        }
      };
      function rewriteOpenZero(path) {
        var node = path.node;
        if (node.from !== 0 || node.to) {
          return;
        }
        node.kind = "*";
        delete node.from;
      }
      function rewriteOpenOne(path) {
        var node = path.node;
        if (node.from !== 1 || node.to) {
          return;
        }
        node.kind = "+";
        delete node.from;
      }
      function rewriteExactOne(path) {
        var node = path.node;
        if (node.from !== 1 || node.to !== 1) {
          return;
        }
        path.parentPath.replace(path.parentPath.node.expression);
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-class-classranges-to-chars-transform.js
  var require_char_class_classranges_to_chars_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-class-classranges-to-chars-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        ClassRange: function ClassRange(path) {
          var node = path.node;
          if (node.from.codePoint === node.to.codePoint) {
            path.replace(node.from);
          } else if (node.from.codePoint === node.to.codePoint - 1) {
            path.getParent().insertChildAt(node.to, path.index + 1);
            path.replace(node.from);
          }
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-class-to-meta-transform.js
  var require_char_class_to_meta_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-class-to-meta-transform.js"(exports, module) {
      "use strict";
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      module.exports = {
        _hasIFlag: false,
        _hasUFlag: false,
        init: function init(ast) {
          this._hasIFlag = ast.flags.includes("i");
          this._hasUFlag = ast.flags.includes("u");
        },
        CharacterClass: function CharacterClass(path) {
          rewriteNumberRanges(path);
          rewriteWordRanges(path, this._hasIFlag, this._hasUFlag);
          rewriteWhitespaceRanges(path);
        }
      };
      function rewriteNumberRanges(path) {
        var node = path.node;
        node.expressions.forEach(function(expression, i) {
          if (isFullNumberRange(expression)) {
            path.getChild(i).replace({
              type: "Char",
              value: "\\d",
              kind: "meta"
            });
          }
        });
      }
      function rewriteWordRanges(path, hasIFlag, hasUFlag) {
        var node = path.node;
        var numberPath = null;
        var lowerCasePath = null;
        var upperCasePath = null;
        var underscorePath = null;
        var u017fPath = null;
        var u212aPath = null;
        node.expressions.forEach(function(expression, i) {
          if (isMetaChar(expression, "\\d")) {
            numberPath = path.getChild(i);
          } else if (isLowerCaseRange(expression)) {
            lowerCasePath = path.getChild(i);
          } else if (isUpperCaseRange(expression)) {
            upperCasePath = path.getChild(i);
          } else if (isUnderscore(expression)) {
            underscorePath = path.getChild(i);
          } else if (hasIFlag && hasUFlag && isCodePoint(expression, 383)) {
            u017fPath = path.getChild(i);
          } else if (hasIFlag && hasUFlag && isCodePoint(expression, 8490)) {
            u212aPath = path.getChild(i);
          }
        });
        if (numberPath && (lowerCasePath && upperCasePath || hasIFlag && (lowerCasePath || upperCasePath)) && underscorePath && (!hasUFlag || !hasIFlag || u017fPath && u212aPath)) {
          numberPath.replace({
            type: "Char",
            value: "\\w",
            kind: "meta"
          });
          if (lowerCasePath) {
            lowerCasePath.remove();
          }
          if (upperCasePath) {
            upperCasePath.remove();
          }
          underscorePath.remove();
          if (u017fPath) {
            u017fPath.remove();
          }
          if (u212aPath) {
            u212aPath.remove();
          }
        }
      }
      var whitespaceRangeTests = [function(node) {
        return isChar(node, " ");
      }].concat(_toConsumableArray(["\\f", "\\n", "\\r", "\\t", "\\v"].map(function(char) {
        return function(node) {
          return isMetaChar(node, char);
        };
      })), _toConsumableArray([160, 5760, 8232, 8233, 8239, 8287, 12288, 65279].map(function(codePoint) {
        return function(node) {
          return isCodePoint(node, codePoint);
        };
      })), [function(node) {
        return node.type === "ClassRange" && isCodePoint(node.from, 8192) && isCodePoint(node.to, 8202);
      }]);
      function rewriteWhitespaceRanges(path) {
        var node = path.node;
        if (node.expressions.length < whitespaceRangeTests.length || !whitespaceRangeTests.every(function(test) {
          return node.expressions.some(function(expression) {
            return test(expression);
          });
        })) {
          return;
        }
        var nNode = node.expressions.find(function(expression) {
          return isMetaChar(expression, "\\n");
        });
        nNode.value = "\\s";
        nNode.symbol = void 0;
        nNode.codePoint = NaN;
        node.expressions.map(function(expression, i) {
          return whitespaceRangeTests.some(function(test) {
            return test(expression);
          }) ? path.getChild(i) : void 0;
        }).filter(Boolean).forEach(function(path2) {
          return path2.remove();
        });
      }
      function isFullNumberRange(node) {
        return node.type === "ClassRange" && node.from.value === "0" && node.to.value === "9";
      }
      function isChar(node, value) {
        var kind = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : "simple";
        return node.type === "Char" && node.value === value && node.kind === kind;
      }
      function isMetaChar(node, value) {
        return isChar(node, value, "meta");
      }
      function isLowerCaseRange(node) {
        return node.type === "ClassRange" && node.from.value === "a" && node.to.value === "z";
      }
      function isUpperCaseRange(node) {
        return node.type === "ClassRange" && node.from.value === "A" && node.to.value === "Z";
      }
      function isUnderscore(node) {
        return node.type === "Char" && node.value === "_" && node.kind === "simple";
      }
      function isCodePoint(node, codePoint) {
        return node.type === "Char" && node.kind === "unicode" && node.codePoint === codePoint;
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-class-to-single-char-transform.js
  var require_char_class_to_single_char_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-class-to-single-char-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        CharacterClass: function CharacterClass(path) {
          var node = path.node;
          if (node.expressions.length !== 1 || !hasAppropriateSiblings(path) || !isAppropriateChar(node.expressions[0])) {
            return;
          }
          var _node$expressions$ = node.expressions[0], value = _node$expressions$.value, kind = _node$expressions$.kind, escaped = _node$expressions$.escaped;
          if (node.negative) {
            if (!isMeta(value)) {
              return;
            }
            value = getInverseMeta(value);
          }
          path.replace({
            type: "Char",
            value,
            kind,
            escaped: escaped || shouldEscape(value)
          });
        }
      };
      function isAppropriateChar(node) {
        return node.type === "Char" && // We don't extract [\b] (backspace) since \b has different
        // semantics (word boundary).
        node.value !== "\\b";
      }
      function isMeta(value) {
        return /^\\[dwsDWS]$/.test(value);
      }
      function getInverseMeta(value) {
        return /[dws]/.test(value) ? value.toUpperCase() : value.toLowerCase();
      }
      function hasAppropriateSiblings(path) {
        var parent = path.parent, index = path.index;
        if (parent.type !== "Alternative") {
          return true;
        }
        var previousNode = parent.expressions[index - 1];
        if (previousNode == null) {
          return true;
        }
        if (previousNode.type === "Backreference" && previousNode.kind === "number") {
          return false;
        }
        if (previousNode.type === "Char" && previousNode.kind === "decimal") {
          return false;
        }
        return true;
      }
      function shouldEscape(value) {
        return /[*[()+?$./{}|]/.test(value);
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-escape-unescape-transform.js
  var require_char_escape_unescape_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-escape-unescape-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        _hasXFlag: false,
        init: function init(ast) {
          this._hasXFlag = ast.flags.includes("x");
        },
        Char: function Char(path) {
          var node = path.node;
          if (!node.escaped) {
            return;
          }
          if (shouldUnescape(path, this._hasXFlag)) {
            delete node.escaped;
          }
        }
      };
      function shouldUnescape(path, hasXFlag) {
        var value = path.node.value, index = path.index, parent = path.parent;
        if (parent.type !== "CharacterClass" && parent.type !== "ClassRange") {
          return !preservesEscape(value, index, parent, hasXFlag);
        }
        return !preservesInCharClass(value, index, parent);
      }
      function preservesInCharClass(value, index, parent) {
        if (value === "^") {
          return index === 0 && !parent.negative;
        }
        if (value === "-") {
          return true;
        }
        return /[\]\\]/.test(value);
      }
      function preservesEscape(value, index, parent, hasXFlag) {
        if (value === "{") {
          return preservesOpeningCurlyBraceEscape(index, parent);
        }
        if (value === "}") {
          return preservesClosingCurlyBraceEscape(index, parent);
        }
        if (hasXFlag && /[ #]/.test(value)) {
          return true;
        }
        return /[*[()+?^$./\\|]/.test(value);
      }
      function consumeNumbers(startIndex, parent, rtl) {
        var i = startIndex;
        var siblingNode = (rtl ? i >= 0 : i < parent.expressions.length) && parent.expressions[i];
        while (siblingNode && siblingNode.type === "Char" && siblingNode.kind === "simple" && !siblingNode.escaped && /\d/.test(siblingNode.value)) {
          rtl ? i-- : i++;
          siblingNode = (rtl ? i >= 0 : i < parent.expressions.length) && parent.expressions[i];
        }
        return Math.abs(startIndex - i);
      }
      function isSimpleChar(node, value) {
        return node && node.type === "Char" && node.kind === "simple" && !node.escaped && node.value === value;
      }
      function preservesOpeningCurlyBraceEscape(index, parent) {
        if (index == null) {
          return false;
        }
        var nbFollowingNumbers = consumeNumbers(index + 1, parent);
        var i = index + nbFollowingNumbers + 1;
        var nextSiblingNode = i < parent.expressions.length && parent.expressions[i];
        if (nbFollowingNumbers) {
          if (isSimpleChar(nextSiblingNode, "}")) {
            return true;
          }
          if (isSimpleChar(nextSiblingNode, ",")) {
            nbFollowingNumbers = consumeNumbers(i + 1, parent);
            i = i + nbFollowingNumbers + 1;
            nextSiblingNode = i < parent.expressions.length && parent.expressions[i];
            return isSimpleChar(nextSiblingNode, "}");
          }
        }
        return false;
      }
      function preservesClosingCurlyBraceEscape(index, parent) {
        if (index == null) {
          return false;
        }
        var nbPrecedingNumbers = consumeNumbers(index - 1, parent, true);
        var i = index - nbPrecedingNumbers - 1;
        var previousSiblingNode = i >= 0 && parent.expressions[i];
        if (nbPrecedingNumbers && isSimpleChar(previousSiblingNode, "{")) {
          return true;
        }
        if (isSimpleChar(previousSiblingNode, ",")) {
          nbPrecedingNumbers = consumeNumbers(i - 1, parent, true);
          i = i - nbPrecedingNumbers - 1;
          previousSiblingNode = i < parent.expressions.length && parent.expressions[i];
          return nbPrecedingNumbers && isSimpleChar(previousSiblingNode, "{");
        }
        return false;
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/char-class-classranges-merge-transform.js
  var require_char_class_classranges_merge_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/char-class-classranges-merge-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        _hasIUFlags: false,
        init: function init(ast) {
          this._hasIUFlags = ast.flags.includes("i") && ast.flags.includes("u");
        },
        CharacterClass: function CharacterClass(path) {
          var node = path.node;
          var expressions = node.expressions;
          var metas = [];
          expressions.forEach(function(expression2) {
            if (isMeta(expression2)) {
              metas.push(expression2.value);
            }
          });
          expressions.sort(sortCharClass);
          for (var i = 0; i < expressions.length; i++) {
            var expression = expressions[i];
            if (fitsInMetas(expression, metas, this._hasIUFlags) || combinesWithPrecedingClassRange(expression, expressions[i - 1]) || combinesWithFollowingClassRange(expression, expressions[i + 1])) {
              expressions.splice(i, 1);
              i--;
            } else {
              var nbMergedChars = charCombinesWithPrecedingChars(expression, i, expressions);
              expressions.splice(i - nbMergedChars + 1, nbMergedChars);
              i -= nbMergedChars;
            }
          }
        }
      };
      function sortCharClass(a, b) {
        var aValue = getSortValue(a);
        var bValue = getSortValue(b);
        if (aValue === bValue) {
          if (a.type === "ClassRange" && b.type !== "ClassRange") {
            return -1;
          }
          if (b.type === "ClassRange" && a.type !== "ClassRange") {
            return 1;
          }
          if (a.type === "ClassRange" && b.type === "ClassRange") {
            return getSortValue(a.to) - getSortValue(b.to);
          }
          if (isMeta(a) && isMeta(b) || isControl(a) && isControl(b)) {
            return a.value < b.value ? -1 : 1;
          }
        }
        return aValue - bValue;
      }
      function getSortValue(expression) {
        if (expression.type === "Char") {
          if (expression.value === "-") {
            return Infinity;
          }
          if (expression.kind === "control") {
            return Infinity;
          }
          if (expression.kind === "meta" && isNaN(expression.codePoint)) {
            return -1;
          }
          return expression.codePoint;
        }
        return expression.from.codePoint;
      }
      function isMeta(expression) {
        var value = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : null;
        return expression.type === "Char" && expression.kind === "meta" && (value ? expression.value === value : /^\\[dws]$/i.test(expression.value));
      }
      function isControl(expression) {
        return expression.type === "Char" && expression.kind === "control";
      }
      function fitsInMetas(expression, metas, hasIUFlags) {
        for (var i = 0; i < metas.length; i++) {
          if (fitsInMeta(expression, metas[i], hasIUFlags)) {
            return true;
          }
        }
        return false;
      }
      function fitsInMeta(expression, meta, hasIUFlags) {
        if (expression.type === "ClassRange") {
          return fitsInMeta(expression.from, meta, hasIUFlags) && fitsInMeta(expression.to, meta, hasIUFlags);
        }
        if (meta === "\\S" && (isMeta(expression, "\\w") || isMeta(expression, "\\d"))) {
          return true;
        }
        if (meta === "\\D" && (isMeta(expression, "\\W") || isMeta(expression, "\\s"))) {
          return true;
        }
        if (meta === "\\w" && isMeta(expression, "\\d")) {
          return true;
        }
        if (meta === "\\W" && isMeta(expression, "\\s")) {
          return true;
        }
        if (expression.type !== "Char" || isNaN(expression.codePoint)) {
          return false;
        }
        if (meta === "\\s") {
          return fitsInMetaS(expression);
        }
        if (meta === "\\S") {
          return !fitsInMetaS(expression);
        }
        if (meta === "\\d") {
          return fitsInMetaD(expression);
        }
        if (meta === "\\D") {
          return !fitsInMetaD(expression);
        }
        if (meta === "\\w") {
          return fitsInMetaW(expression, hasIUFlags);
        }
        if (meta === "\\W") {
          return !fitsInMetaW(expression, hasIUFlags);
        }
        return false;
      }
      function fitsInMetaS(expression) {
        return expression.codePoint === 9 || // \t
        expression.codePoint === 10 || // \n
        expression.codePoint === 11 || // \v
        expression.codePoint === 12 || // \f
        expression.codePoint === 13 || // \r
        expression.codePoint === 32 || // space
        expression.codePoint === 160 || // nbsp
        expression.codePoint === 5760 || // part of Zs
        expression.codePoint >= 8192 && expression.codePoint <= 8202 || // part of Zs
        expression.codePoint === 8232 || // line separator
        expression.codePoint === 8233 || // paragraph separator
        expression.codePoint === 8239 || // part of Zs
        expression.codePoint === 8287 || // part of Zs
        expression.codePoint === 12288 || // part of Zs
        expression.codePoint === 65279;
      }
      function fitsInMetaD(expression) {
        return expression.codePoint >= 48 && expression.codePoint <= 57;
      }
      function fitsInMetaW(expression, hasIUFlags) {
        return fitsInMetaD(expression) || expression.codePoint >= 65 && expression.codePoint <= 90 || // A-Z
        expression.codePoint >= 97 && expression.codePoint <= 122 || // a-z
        expression.value === "_" || hasIUFlags && (expression.codePoint === 383 || expression.codePoint === 8490);
      }
      function combinesWithPrecedingClassRange(expression, classRange) {
        if (classRange && classRange.type === "ClassRange") {
          if (fitsInClassRange(expression, classRange)) {
            return true;
          } else if (
            // We only want \w chars or char codes to keep readability
            isMetaWCharOrCode(expression) && classRange.to.codePoint === expression.codePoint - 1
          ) {
            classRange.to = expression;
            return true;
          } else if (expression.type === "ClassRange" && expression.from.codePoint <= classRange.to.codePoint + 1 && expression.to.codePoint >= classRange.from.codePoint - 1) {
            if (expression.from.codePoint < classRange.from.codePoint) {
              classRange.from = expression.from;
            }
            if (expression.to.codePoint > classRange.to.codePoint) {
              classRange.to = expression.to;
            }
            return true;
          }
        }
        return false;
      }
      function combinesWithFollowingClassRange(expression, classRange) {
        if (classRange && classRange.type === "ClassRange") {
          if (
            // We only want \w chars or char codes to keep readability
            isMetaWCharOrCode(expression) && classRange.from.codePoint === expression.codePoint + 1
          ) {
            classRange.from = expression;
            return true;
          }
        }
        return false;
      }
      function fitsInClassRange(expression, classRange) {
        if (expression.type === "Char" && isNaN(expression.codePoint)) {
          return false;
        }
        if (expression.type === "ClassRange") {
          return fitsInClassRange(expression.from, classRange) && fitsInClassRange(expression.to, classRange);
        }
        return expression.codePoint >= classRange.from.codePoint && expression.codePoint <= classRange.to.codePoint;
      }
      function charCombinesWithPrecedingChars(expression, index, expressions) {
        if (!isMetaWCharOrCode(expression)) {
          return 0;
        }
        var nbMergedChars = 0;
        while (index > 0) {
          var currentExpression = expressions[index];
          var precedingExpresion = expressions[index - 1];
          if (isMetaWCharOrCode(precedingExpresion) && precedingExpresion.codePoint === currentExpression.codePoint - 1) {
            nbMergedChars++;
            index--;
          } else {
            break;
          }
        }
        if (nbMergedChars > 1) {
          expressions[index] = {
            type: "ClassRange",
            from: expressions[index],
            to: expression
          };
          return nbMergedChars;
        }
        return 0;
      }
      function isMetaWCharOrCode(expression) {
        return expression && expression.type === "Char" && !isNaN(expression.codePoint) && (fitsInMetaW(expression, false) || expression.kind === "unicode" || expression.kind === "hex" || expression.kind === "oct" || expression.kind === "decimal");
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/disjunction-remove-duplicates-transform.js
  var require_disjunction_remove_duplicates_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/disjunction-remove-duplicates-transform.js"(exports, module) {
      "use strict";
      var NodePath = require_node_path();
      var _require = require_utils2();
      var disjunctionToList = _require.disjunctionToList;
      var listToDisjunction = _require.listToDisjunction;
      module.exports = {
        Disjunction: function Disjunction(path) {
          var node = path.node;
          var uniqueNodesMap = {};
          var parts = disjunctionToList(node).filter(function(part) {
            var encoded = part ? NodePath.getForNode(part).jsonEncode() : "null";
            if (uniqueNodesMap.hasOwnProperty(encoded)) {
              return false;
            }
            uniqueNodesMap[encoded] = part;
            return true;
          });
          path.replace(listToDisjunction(parts));
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/group-single-chars-to-char-class.js
  var require_group_single_chars_to_char_class = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/group-single-chars-to-char-class.js"(exports, module) {
      "use strict";
      module.exports = {
        Disjunction: function Disjunction(path) {
          var node = path.node, parent = path.parent;
          if (!handlers[parent.type]) {
            return;
          }
          var charset = /* @__PURE__ */ new Map();
          if (!shouldProcess(node, charset) || !charset.size) {
            return;
          }
          var characterClass = {
            type: "CharacterClass",
            expressions: Array.from(charset.keys()).sort().map(function(key) {
              return charset.get(key);
            })
          };
          handlers[parent.type](path.getParent(), characterClass);
        }
      };
      var handlers = {
        RegExp: function RegExp2(path, characterClass) {
          var node = path.node;
          node.body = characterClass;
        },
        Group: function Group3(path, characterClass) {
          var node = path.node;
          if (node.capturing) {
            node.expression = characterClass;
          } else {
            path.replace(characterClass);
          }
        }
      };
      function shouldProcess(expression, charset) {
        if (!expression) {
          return false;
        }
        var type = expression.type;
        if (type === "Disjunction") {
          var left = expression.left, right = expression.right;
          return shouldProcess(left, charset) && shouldProcess(right, charset);
        } else if (type === "Char") {
          if (expression.kind === "meta" && expression.symbol === ".") {
            return false;
          }
          var value = expression.value;
          charset.set(value, expression);
          return true;
        } else if (type === "CharacterClass" && !expression.negative) {
          return expression.expressions.every(function(expression2) {
            return shouldProcess(expression2, charset);
          });
        }
        return false;
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/remove-empty-group-transform.js
  var require_remove_empty_group_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/remove-empty-group-transform.js"(exports, module) {
      "use strict";
      module.exports = {
        Group: function Group3(path) {
          var node = path.node, parent = path.parent;
          var childPath = path.getChild();
          if (node.capturing || childPath) {
            return;
          }
          if (parent.type === "Repetition") {
            path.getParent().replace(node);
          } else if (parent.type !== "RegExp") {
            path.remove();
          }
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/ungroup-transform.js
  var require_ungroup_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/ungroup-transform.js"(exports, module) {
      "use strict";
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      module.exports = {
        Group: function Group3(path) {
          var node = path.node, parent = path.parent;
          var childPath = path.getChild();
          if (node.capturing || !childPath) {
            return;
          }
          if (!hasAppropriateSiblings(path)) {
            return;
          }
          if (childPath.node.type === "Disjunction" && parent.type !== "RegExp") {
            return;
          }
          if (parent.type === "Repetition" && childPath.node.type !== "Char" && childPath.node.type !== "CharacterClass") {
            return;
          }
          if (childPath.node.type === "Alternative") {
            var parentPath = path.getParent();
            if (parentPath.node.type === "Alternative") {
              parentPath.replace({
                type: "Alternative",
                expressions: [].concat(_toConsumableArray(parent.expressions.slice(0, path.index)), _toConsumableArray(childPath.node.expressions), _toConsumableArray(parent.expressions.slice(path.index + 1)))
              });
            }
          } else {
            path.replace(childPath.node);
          }
        }
      };
      function hasAppropriateSiblings(path) {
        var parent = path.parent, index = path.index;
        if (parent.type !== "Alternative") {
          return true;
        }
        var previousNode = parent.expressions[index - 1];
        if (previousNode == null) {
          return true;
        }
        if (previousNode.type === "Backreference" && previousNode.kind === "number") {
          return false;
        }
        if (previousNode.type === "Char" && previousNode.kind === "decimal") {
          return false;
        }
        return true;
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/combine-repeating-patterns-transform.js
  var require_combine_repeating_patterns_transform = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/combine-repeating-patterns-transform.js"(exports, module) {
      "use strict";
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      var NodePath = require_node_path();
      var _require = require_utils2();
      var increaseQuantifierByOne = _require.increaseQuantifierByOne;
      module.exports = {
        Alternative: function Alternative(path) {
          var node = path.node;
          var index = 1;
          while (index < node.expressions.length) {
            var child = path.getChild(index);
            index = Math.max(1, combineRepeatingPatternLeft(path, child, index));
            if (index >= node.expressions.length) {
              break;
            }
            child = path.getChild(index);
            index = Math.max(1, combineWithPreviousRepetition(path, child, index));
            if (index >= node.expressions.length) {
              break;
            }
            child = path.getChild(index);
            index = Math.max(1, combineRepetitionWithPrevious(path, child, index));
            index++;
          }
        }
      };
      function combineRepeatingPatternLeft(alternative, child, index) {
        var node = alternative.node;
        var nbPossibleLengths = Math.ceil(index / 2);
        var i = 0;
        while (i < nbPossibleLengths) {
          var startIndex = index - 2 * i - 1;
          var right = void 0, left = void 0;
          if (i === 0) {
            right = child;
            left = alternative.getChild(startIndex);
          } else {
            right = NodePath.getForNode({
              type: "Alternative",
              expressions: [].concat(_toConsumableArray(node.expressions.slice(index - i, index)), [child.node])
            });
            left = NodePath.getForNode({
              type: "Alternative",
              expressions: [].concat(_toConsumableArray(node.expressions.slice(startIndex, index - i)))
            });
          }
          if (right.hasEqualSource(left)) {
            for (var j = 0; j < 2 * i + 1; j++) {
              alternative.getChild(startIndex).remove();
            }
            child.replace({
              type: "Repetition",
              expression: i === 0 && right.node.type !== "Repetition" ? right.node : {
                type: "Group",
                capturing: false,
                expression: right.node
              },
              quantifier: {
                type: "Quantifier",
                kind: "Range",
                from: 2,
                to: 2,
                greedy: true
              }
            });
            return startIndex;
          }
          i++;
        }
        return index;
      }
      function combineWithPreviousRepetition(alternative, child, index) {
        var node = alternative.node;
        var i = 0;
        while (i < index) {
          var previousChild = alternative.getChild(i);
          if (previousChild.node.type === "Repetition" && previousChild.node.quantifier.greedy) {
            var left = previousChild.getChild();
            var right = void 0;
            if (left.node.type === "Group" && !left.node.capturing) {
              left = left.getChild();
            }
            if (i + 1 === index) {
              right = child;
              if (right.node.type === "Group" && !right.node.capturing) {
                right = right.getChild();
              }
            } else {
              right = NodePath.getForNode({
                type: "Alternative",
                expressions: [].concat(_toConsumableArray(node.expressions.slice(i + 1, index + 1)))
              });
            }
            if (left.hasEqualSource(right)) {
              for (var j = i; j < index; j++) {
                alternative.getChild(i + 1).remove();
              }
              increaseQuantifierByOne(previousChild.node.quantifier);
              return i;
            }
          }
          i++;
        }
        return index;
      }
      function combineRepetitionWithPrevious(alternative, child, index) {
        var node = alternative.node;
        if (child.node.type === "Repetition" && child.node.quantifier.greedy) {
          var right = child.getChild();
          var left = void 0;
          if (right.node.type === "Group" && !right.node.capturing) {
            right = right.getChild();
          }
          var rightLength = void 0;
          if (right.node.type === "Alternative") {
            rightLength = right.node.expressions.length;
            left = NodePath.getForNode({
              type: "Alternative",
              expressions: [].concat(_toConsumableArray(node.expressions.slice(index - rightLength, index)))
            });
          } else {
            rightLength = 1;
            left = alternative.getChild(index - 1);
            if (left.node.type === "Group" && !left.node.capturing) {
              left = left.getChild();
            }
          }
          if (left.hasEqualSource(right)) {
            for (var j = index - rightLength; j < index; j++) {
              alternative.getChild(index - rightLength).remove();
            }
            increaseQuantifierByOne(child.node.quantifier);
            return index - rightLength;
          }
        }
        return index;
      }
    }
  });

  // node_modules/regexp-tree/dist/optimizer/transforms/index.js
  var require_transforms2 = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/transforms/index.js"(exports, module) {
      "use strict";
      module.exports = /* @__PURE__ */ new Map([
        // \ud83d\ude80 -> \u{1f680}
        ["charSurrogatePairToSingleUnicode", require_char_surrogate_pair_to_single_unicode_transform()],
        // \u0061 -> a
        ["charCodeToSimpleChar", require_char_code_to_simple_char_transform()],
        // /Aa/i -> /aa/i
        ["charCaseInsensitiveLowerCaseTransform", require_char_case_insensitive_lowercase_transform()],
        // [\d\d] -> [\d]
        ["charClassRemoveDuplicates", require_char_class_remove_duplicates_transform()],
        // a{1,2}a{2,3} -> a{3,5}
        ["quantifiersMerge", require_quantifiers_merge_transform()],
        // a{1,} -> a+, a{3,3} -> a{3}, a{1} -> a
        ["quantifierRangeToSymbol", require_quantifier_range_to_symbol_transform()],
        // [a-a] -> [a], [a-b] -> [ab]
        ["charClassClassrangesToChars", require_char_class_classranges_to_chars_transform()],
        // [0-9] -> [\d]
        ["charClassToMeta", require_char_class_to_meta_transform()],
        // [\d] -> \d, [^\w] -> \W
        ["charClassToSingleChar", require_char_class_to_single_char_transform()],
        // \e -> e
        ["charEscapeUnescape", require_char_escape_unescape_transform()],
        // [a-de-f] -> [a-f]
        ["charClassClassrangesMerge", require_char_class_classranges_merge_transform()],
        // (ab|ab) -> (ab)
        ["disjunctionRemoveDuplicates", require_disjunction_remove_duplicates_transform()],
        // (a|b|c) -> [abc]
        ["groupSingleCharsToCharClass", require_group_single_chars_to_char_class()],
        // (?:)a -> a
        ["removeEmptyGroup", require_remove_empty_group_transform()],
        // (?:a) -> a
        ["ungroup", require_ungroup_transform()],
        // abcabcabc -> (?:abc){3}
        ["combineRepeatingPatterns", require_combine_repeating_patterns_transform()]
      ]);
    }
  });

  // node_modules/regexp-tree/dist/optimizer/index.js
  var require_optimizer = __commonJS({
    "node_modules/regexp-tree/dist/optimizer/index.js"(exports, module) {
      "use strict";
      var clone = require_clone();
      var parser = require_parser();
      var transform = require_transform();
      var optimizationTransforms = require_transforms2();
      module.exports = {
        /**
         * Optimizer transforms a regular expression into an optimized version,
         * replacing some sub-expressions with their idiomatic patterns.
         *
         * @param string | RegExp | AST - a regexp to optimize.
         *
         * @return TransformResult - an optimized regexp.
         *
         * Example:
         *
         *   /[a-zA-Z_0-9][a-zA-Z_0-9]*\e{1,}/
         *
         * Optimized to:
         *
         *   /\w+e+/
         */
        optimize: function optimize(regexp) {
          var _ref = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : {}, _ref$whitelist = _ref.whitelist, whitelist = _ref$whitelist === void 0 ? [] : _ref$whitelist, _ref$blacklist = _ref.blacklist, blacklist = _ref$blacklist === void 0 ? [] : _ref$blacklist;
          var transformsRaw = whitelist.length > 0 ? whitelist : Array.from(optimizationTransforms.keys());
          var transformToApply = transformsRaw.filter(function(transform2) {
            return !blacklist.includes(transform2);
          });
          var ast = regexp;
          if (regexp instanceof RegExp) {
            regexp = "" + regexp;
          }
          if (typeof regexp === "string") {
            ast = parser.parse(regexp);
          }
          var result = new transform.TransformResult(ast);
          var prevResultString = void 0;
          do {
            prevResultString = result.toString();
            ast = clone(result.getAST());
            transformToApply.forEach(function(transformName) {
              if (!optimizationTransforms.has(transformName)) {
                throw new Error("Unknown optimization-transform: " + transformName + ". Available transforms are: " + Array.from(optimizationTransforms.keys()).join(", "));
              }
              var transformer = optimizationTransforms.get(transformName);
              var newResult = transform.transform(ast, transformer);
              if (newResult.toString() !== result.toString()) {
                if (newResult.toString().length <= result.toString().length) {
                  result = newResult;
                } else {
                  ast = clone(result.getAST());
                }
              }
            });
          } while (result.toString() !== prevResultString);
          return result;
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/special-symbols.js
  var require_special_symbols = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/special-symbols.js"(exports, module) {
      "use strict";
      var EPSILON = "\u03B5";
      var EPSILON_CLOSURE = EPSILON + "*";
      module.exports = {
        EPSILON,
        EPSILON_CLOSURE
      };
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/nfa.js
  var require_nfa = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/nfa.js"(exports, module) {
      "use strict";
      var _slicedToArray = /* @__PURE__ */ (function() {
        function sliceIterator(arr, i) {
          var _arr = [];
          var _n = true;
          var _d = false;
          var _e = void 0;
          try {
            for (var _i = arr[Symbol.iterator](), _s; !(_n = (_s = _i.next()).done); _n = true) {
              _arr.push(_s.value);
              if (i && _arr.length === i) break;
            }
          } catch (err) {
            _d = true;
            _e = err;
          } finally {
            try {
              if (!_n && _i["return"]) _i["return"]();
            } finally {
              if (_d) throw _e;
            }
          }
          return _arr;
        }
        return function(arr, i) {
          if (Array.isArray(arr)) {
            return arr;
          } else if (Symbol.iterator in Object(arr)) {
            return sliceIterator(arr, i);
          } else {
            throw new TypeError("Invalid attempt to destructure non-iterable instance");
          }
        };
      })();
      var _createClass = /* @__PURE__ */ (function() {
        function defineProperties(target, props) {
          for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
          }
        }
        return function(Constructor, protoProps, staticProps) {
          if (protoProps) defineProperties(Constructor.prototype, protoProps);
          if (staticProps) defineProperties(Constructor, staticProps);
          return Constructor;
        };
      })();
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
          throw new TypeError("Cannot call a class as a function");
        }
      }
      var _require = require_special_symbols();
      var EPSILON = _require.EPSILON;
      var EPSILON_CLOSURE = _require.EPSILON_CLOSURE;
      var NFA = (function() {
        function NFA2(inState, outState) {
          _classCallCheck(this, NFA2);
          this.in = inState;
          this.out = outState;
        }
        _createClass(NFA2, [{
          key: "matches",
          value: function matches(string) {
            return this.in.matches(string);
          }
          /**
           * Returns an alphabet for this NFA.
           */
        }, {
          key: "getAlphabet",
          value: function getAlphabet() {
            if (!this._alphabet) {
              this._alphabet = /* @__PURE__ */ new Set();
              var table = this.getTransitionTable();
              for (var state in table) {
                var transitions = table[state];
                for (var symbol in transitions) {
                  if (symbol !== EPSILON_CLOSURE) {
                    this._alphabet.add(symbol);
                  }
                }
              }
            }
            return this._alphabet;
          }
          /**
           * Returns set of accepting states.
           */
        }, {
          key: "getAcceptingStates",
          value: function getAcceptingStates() {
            if (!this._acceptingStates) {
              this.getTransitionTable();
            }
            return this._acceptingStates;
          }
          /**
           * Returns accepting state numbers.
           */
        }, {
          key: "getAcceptingStateNumbers",
          value: function getAcceptingStateNumbers() {
            if (!this._acceptingStateNumbers) {
              this._acceptingStateNumbers = /* @__PURE__ */ new Set();
              var _iteratorNormalCompletion = true;
              var _didIteratorError = false;
              var _iteratorError = void 0;
              try {
                for (var _iterator = this.getAcceptingStates()[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
                  var acceptingState = _step.value;
                  this._acceptingStateNumbers.add(acceptingState.number);
                }
              } catch (err) {
                _didIteratorError = true;
                _iteratorError = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion && _iterator.return) {
                    _iterator.return();
                  }
                } finally {
                  if (_didIteratorError) {
                    throw _iteratorError;
                  }
                }
              }
            }
            return this._acceptingStateNumbers;
          }
          /**
           * Builds and returns transition table.
           */
        }, {
          key: "getTransitionTable",
          value: function getTransitionTable() {
            var _this = this;
            if (!this._transitionTable) {
              this._transitionTable = {};
              this._acceptingStates = /* @__PURE__ */ new Set();
              var visited = /* @__PURE__ */ new Set();
              var symbols = /* @__PURE__ */ new Set();
              var visitState = function visitState2(state) {
                if (visited.has(state)) {
                  return;
                }
                visited.add(state);
                state.number = visited.size;
                _this._transitionTable[state.number] = {};
                if (state.accepting) {
                  _this._acceptingStates.add(state);
                }
                var transitions = state.getTransitions();
                var _iteratorNormalCompletion2 = true;
                var _didIteratorError2 = false;
                var _iteratorError2 = void 0;
                try {
                  for (var _iterator2 = transitions[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
                    var _ref = _step2.value;
                    var _ref2 = _slicedToArray(_ref, 2);
                    var symbol = _ref2[0];
                    var symbolTransitions = _ref2[1];
                    var combinedState = [];
                    symbols.add(symbol);
                    var _iteratorNormalCompletion3 = true;
                    var _didIteratorError3 = false;
                    var _iteratorError3 = void 0;
                    try {
                      for (var _iterator3 = symbolTransitions[Symbol.iterator](), _step3; !(_iteratorNormalCompletion3 = (_step3 = _iterator3.next()).done); _iteratorNormalCompletion3 = true) {
                        var nextState = _step3.value;
                        visitState2(nextState);
                        combinedState.push(nextState.number);
                      }
                    } catch (err) {
                      _didIteratorError3 = true;
                      _iteratorError3 = err;
                    } finally {
                      try {
                        if (!_iteratorNormalCompletion3 && _iterator3.return) {
                          _iterator3.return();
                        }
                      } finally {
                        if (_didIteratorError3) {
                          throw _iteratorError3;
                        }
                      }
                    }
                    _this._transitionTable[state.number][symbol] = combinedState;
                  }
                } catch (err) {
                  _didIteratorError2 = true;
                  _iteratorError2 = err;
                } finally {
                  try {
                    if (!_iteratorNormalCompletion2 && _iterator2.return) {
                      _iterator2.return();
                    }
                  } finally {
                    if (_didIteratorError2) {
                      throw _iteratorError2;
                    }
                  }
                }
              };
              visitState(this.in);
              visited.forEach(function(state) {
                delete _this._transitionTable[state.number][EPSILON];
                _this._transitionTable[state.number][EPSILON_CLOSURE] = [].concat(_toConsumableArray(state.getEpsilonClosure())).map(function(s) {
                  return s.number;
                });
              });
            }
            return this._transitionTable;
          }
        }]);
        return NFA2;
      })();
      module.exports = NFA;
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/dfa/dfa-minimizer.js
  var require_dfa_minimizer = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/dfa/dfa-minimizer.js"(exports, module) {
      "use strict";
      var _slicedToArray = /* @__PURE__ */ (function() {
        function sliceIterator(arr, i) {
          var _arr = [];
          var _n = true;
          var _d = false;
          var _e = void 0;
          try {
            for (var _i = arr[Symbol.iterator](), _s; !(_n = (_s = _i.next()).done); _n = true) {
              _arr.push(_s.value);
              if (i && _arr.length === i) break;
            }
          } catch (err) {
            _d = true;
            _e = err;
          } finally {
            try {
              if (!_n && _i["return"]) _i["return"]();
            } finally {
              if (_d) throw _e;
            }
          }
          return _arr;
        }
        return function(arr, i) {
          if (Array.isArray(arr)) {
            return arr;
          } else if (Symbol.iterator in Object(arr)) {
            return sliceIterator(arr, i);
          } else {
            throw new TypeError("Invalid attempt to destructure non-iterable instance");
          }
        };
      })();
      function _toArray(arr) {
        return Array.isArray(arr) ? arr : Array.from(arr);
      }
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      var currentTransitionMap = null;
      function minimize(dfa) {
        var table = dfa.getTransitionTable();
        var allStates = Object.keys(table);
        var alphabet = dfa.getAlphabet();
        var accepting = dfa.getAcceptingStateNumbers();
        currentTransitionMap = {};
        var nonAccepting = /* @__PURE__ */ new Set();
        allStates.forEach(function(state) {
          state = Number(state);
          var isAccepting = accepting.has(state);
          if (isAccepting) {
            currentTransitionMap[state] = accepting;
          } else {
            nonAccepting.add(state);
            currentTransitionMap[state] = nonAccepting;
          }
        });
        var all = [
          // 0-equivalent sets.
          [nonAccepting, accepting].filter(function(set2) {
            return set2.size > 0;
          })
        ];
        var current = void 0;
        var previous = void 0;
        current = all[all.length - 1];
        previous = all[all.length - 2];
        var _loop = function _loop2() {
          var newTransitionMap = {};
          var _iteratorNormalCompletion3 = true;
          var _didIteratorError3 = false;
          var _iteratorError3 = void 0;
          try {
            for (var _iterator3 = current[Symbol.iterator](), _step3; !(_iteratorNormalCompletion3 = (_step3 = _iterator3.next()).done); _iteratorNormalCompletion3 = true) {
              var _set = _step3.value;
              var handledStates = {};
              var _set2 = _toArray(_set), first = _set2[0], rest = _set2.slice(1);
              handledStates[first] = /* @__PURE__ */ new Set([first]);
              var _iteratorNormalCompletion4 = true;
              var _didIteratorError4 = false;
              var _iteratorError4 = void 0;
              try {
                restSets: for (var _iterator4 = rest[Symbol.iterator](), _step4; !(_iteratorNormalCompletion4 = (_step4 = _iterator4.next()).done); _iteratorNormalCompletion4 = true) {
                  var state = _step4.value;
                  var _iteratorNormalCompletion5 = true;
                  var _didIteratorError5 = false;
                  var _iteratorError5 = void 0;
                  try {
                    for (var _iterator5 = Object.keys(handledStates)[Symbol.iterator](), _step5; !(_iteratorNormalCompletion5 = (_step5 = _iterator5.next()).done); _iteratorNormalCompletion5 = true) {
                      var handledState = _step5.value;
                      if (areEquivalent(state, handledState, table, alphabet)) {
                        handledStates[handledState].add(state);
                        handledStates[state] = handledStates[handledState];
                        continue restSets;
                      }
                    }
                  } catch (err) {
                    _didIteratorError5 = true;
                    _iteratorError5 = err;
                  } finally {
                    try {
                      if (!_iteratorNormalCompletion5 && _iterator5.return) {
                        _iterator5.return();
                      }
                    } finally {
                      if (_didIteratorError5) {
                        throw _iteratorError5;
                      }
                    }
                  }
                  handledStates[state] = /* @__PURE__ */ new Set([state]);
                }
              } catch (err) {
                _didIteratorError4 = true;
                _iteratorError4 = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion4 && _iterator4.return) {
                    _iterator4.return();
                  }
                } finally {
                  if (_didIteratorError4) {
                    throw _iteratorError4;
                  }
                }
              }
              Object.assign(newTransitionMap, handledStates);
            }
          } catch (err) {
            _didIteratorError3 = true;
            _iteratorError3 = err;
          } finally {
            try {
              if (!_iteratorNormalCompletion3 && _iterator3.return) {
                _iterator3.return();
              }
            } finally {
              if (_didIteratorError3) {
                throw _iteratorError3;
              }
            }
          }
          currentTransitionMap = newTransitionMap;
          var newSets = new Set(Object.keys(newTransitionMap).map(function(state2) {
            return newTransitionMap[state2];
          }));
          all.push([].concat(_toConsumableArray(newSets)));
          current = all[all.length - 1];
          previous = all[all.length - 2];
        };
        while (!sameRow(current, previous)) {
          _loop();
        }
        var remaped = /* @__PURE__ */ new Map();
        var idx = 1;
        current.forEach(function(set2) {
          return remaped.set(set2, idx++);
        });
        var minimizedTable = {};
        var minimizedAcceptingStates = /* @__PURE__ */ new Set();
        var updateAcceptingStates = function updateAcceptingStates2(set2, idx2) {
          var _iteratorNormalCompletion = true;
          var _didIteratorError = false;
          var _iteratorError = void 0;
          try {
            for (var _iterator = set2[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
              var state = _step.value;
              if (accepting.has(state)) {
                minimizedAcceptingStates.add(idx2);
              }
            }
          } catch (err) {
            _didIteratorError = true;
            _iteratorError = err;
          } finally {
            try {
              if (!_iteratorNormalCompletion && _iterator.return) {
                _iterator.return();
              }
            } finally {
              if (_didIteratorError) {
                throw _iteratorError;
              }
            }
          }
        };
        var _iteratorNormalCompletion2 = true;
        var _didIteratorError2 = false;
        var _iteratorError2 = void 0;
        try {
          for (var _iterator2 = remaped.entries()[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
            var _ref = _step2.value;
            var _ref2 = _slicedToArray(_ref, 2);
            var set = _ref2[0];
            var _idx = _ref2[1];
            minimizedTable[_idx] = {};
            var _iteratorNormalCompletion6 = true;
            var _didIteratorError6 = false;
            var _iteratorError6 = void 0;
            try {
              for (var _iterator6 = alphabet[Symbol.iterator](), _step6; !(_iteratorNormalCompletion6 = (_step6 = _iterator6.next()).done); _iteratorNormalCompletion6 = true) {
                var symbol = _step6.value;
                updateAcceptingStates(set, _idx);
                var originalTransition = void 0;
                var _iteratorNormalCompletion7 = true;
                var _didIteratorError7 = false;
                var _iteratorError7 = void 0;
                try {
                  for (var _iterator7 = set[Symbol.iterator](), _step7; !(_iteratorNormalCompletion7 = (_step7 = _iterator7.next()).done); _iteratorNormalCompletion7 = true) {
                    var originalState = _step7.value;
                    originalTransition = table[originalState][symbol];
                    if (originalTransition) {
                      break;
                    }
                  }
                } catch (err) {
                  _didIteratorError7 = true;
                  _iteratorError7 = err;
                } finally {
                  try {
                    if (!_iteratorNormalCompletion7 && _iterator7.return) {
                      _iterator7.return();
                    }
                  } finally {
                    if (_didIteratorError7) {
                      throw _iteratorError7;
                    }
                  }
                }
                if (originalTransition) {
                  minimizedTable[_idx][symbol] = remaped.get(currentTransitionMap[originalTransition]);
                }
              }
            } catch (err) {
              _didIteratorError6 = true;
              _iteratorError6 = err;
            } finally {
              try {
                if (!_iteratorNormalCompletion6 && _iterator6.return) {
                  _iterator6.return();
                }
              } finally {
                if (_didIteratorError6) {
                  throw _iteratorError6;
                }
              }
            }
          }
        } catch (err) {
          _didIteratorError2 = true;
          _iteratorError2 = err;
        } finally {
          try {
            if (!_iteratorNormalCompletion2 && _iterator2.return) {
              _iterator2.return();
            }
          } finally {
            if (_didIteratorError2) {
              throw _iteratorError2;
            }
          }
        }
        dfa.setTransitionTable(minimizedTable);
        dfa.setAcceptingStateNumbers(minimizedAcceptingStates);
        return dfa;
      }
      function sameRow(r1, r2) {
        if (!r2) {
          return false;
        }
        if (r1.length !== r2.length) {
          return false;
        }
        for (var i = 0; i < r1.length; i++) {
          var s1 = r1[i];
          var s2 = r2[i];
          if (s1.size !== s2.size) {
            return false;
          }
          if ([].concat(_toConsumableArray(s1)).sort().join(",") !== [].concat(_toConsumableArray(s2)).sort().join(",")) {
            return false;
          }
        }
        return true;
      }
      function areEquivalent(s1, s2, table, alphabet) {
        var _iteratorNormalCompletion8 = true;
        var _didIteratorError8 = false;
        var _iteratorError8 = void 0;
        try {
          for (var _iterator8 = alphabet[Symbol.iterator](), _step8; !(_iteratorNormalCompletion8 = (_step8 = _iterator8.next()).done); _iteratorNormalCompletion8 = true) {
            var symbol = _step8.value;
            if (!goToSameSet(s1, s2, table, symbol)) {
              return false;
            }
          }
        } catch (err) {
          _didIteratorError8 = true;
          _iteratorError8 = err;
        } finally {
          try {
            if (!_iteratorNormalCompletion8 && _iterator8.return) {
              _iterator8.return();
            }
          } finally {
            if (_didIteratorError8) {
              throw _iteratorError8;
            }
          }
        }
        return true;
      }
      function goToSameSet(s1, s2, table, symbol) {
        if (!currentTransitionMap[s1] || !currentTransitionMap[s2]) {
          return false;
        }
        var originalTransitionS1 = table[s1][symbol];
        var originalTransitionS2 = table[s2][symbol];
        if (!originalTransitionS1 && !originalTransitionS2) {
          return true;
        }
        return currentTransitionMap[s1].has(originalTransitionS1) && currentTransitionMap[s2].has(originalTransitionS2);
      }
      module.exports = {
        minimize
      };
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/dfa/dfa.js
  var require_dfa = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/dfa/dfa.js"(exports, module) {
      "use strict";
      var _createClass = /* @__PURE__ */ (function() {
        function defineProperties(target, props) {
          for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
          }
        }
        return function(Constructor, protoProps, staticProps) {
          if (protoProps) defineProperties(Constructor.prototype, protoProps);
          if (staticProps) defineProperties(Constructor, staticProps);
          return Constructor;
        };
      })();
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
          throw new TypeError("Cannot call a class as a function");
        }
      }
      var DFAMinimizer = require_dfa_minimizer();
      var _require = require_special_symbols();
      var EPSILON_CLOSURE = _require.EPSILON_CLOSURE;
      var DFA = (function() {
        function DFA2(nfa) {
          _classCallCheck(this, DFA2);
          this._nfa = nfa;
        }
        _createClass(DFA2, [{
          key: "minimize",
          value: function minimize() {
            this.getTransitionTable();
            this._originalAcceptingStateNumbers = this._acceptingStateNumbers;
            this._originalTransitionTable = this._transitionTable;
            DFAMinimizer.minimize(this);
          }
          /**
           * Returns alphabet for this DFA.
           */
        }, {
          key: "getAlphabet",
          value: function getAlphabet() {
            return this._nfa.getAlphabet();
          }
          /**
           * Returns accepting states.
           */
        }, {
          key: "getAcceptingStateNumbers",
          value: function getAcceptingStateNumbers() {
            if (!this._acceptingStateNumbers) {
              this.getTransitionTable();
            }
            return this._acceptingStateNumbers;
          }
          /**
           * Returns original accepting states.
           */
        }, {
          key: "getOriginaAcceptingStateNumbers",
          value: function getOriginaAcceptingStateNumbers() {
            if (!this._originalAcceptingStateNumbers) {
              this.getTransitionTable();
            }
            return this._originalAcceptingStateNumbers;
          }
          /**
           * Sets transition table.
           */
        }, {
          key: "setTransitionTable",
          value: function setTransitionTable(table) {
            this._transitionTable = table;
          }
          /**
           * Sets accepting states.
           */
        }, {
          key: "setAcceptingStateNumbers",
          value: function setAcceptingStateNumbers(stateNumbers) {
            this._acceptingStateNumbers = stateNumbers;
          }
          /**
           * DFA transition table is built from NFA table.
           */
        }, {
          key: "getTransitionTable",
          value: function getTransitionTable() {
            var _this = this;
            if (this._transitionTable) {
              return this._transitionTable;
            }
            var nfaTable = this._nfa.getTransitionTable();
            var nfaStates = Object.keys(nfaTable);
            this._acceptingStateNumbers = /* @__PURE__ */ new Set();
            var startState = nfaTable[nfaStates[0]][EPSILON_CLOSURE];
            var worklist = [startState];
            var alphabet = this.getAlphabet();
            var nfaAcceptingStates = this._nfa.getAcceptingStateNumbers();
            var dfaTable = {};
            var updateAcceptingStates = function updateAcceptingStates2(states2) {
              var _iteratorNormalCompletion = true;
              var _didIteratorError = false;
              var _iteratorError = void 0;
              try {
                for (var _iterator = nfaAcceptingStates[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
                  var nfaAcceptingState = _step.value;
                  if (states2.indexOf(nfaAcceptingState) !== -1) {
                    _this._acceptingStateNumbers.add(states2.join(","));
                    break;
                  }
                }
              } catch (err) {
                _didIteratorError = true;
                _iteratorError = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion && _iterator.return) {
                    _iterator.return();
                  }
                } finally {
                  if (_didIteratorError) {
                    throw _iteratorError;
                  }
                }
              }
            };
            while (worklist.length > 0) {
              var states = worklist.shift();
              var dfaStateLabel = states.join(",");
              dfaTable[dfaStateLabel] = {};
              var _iteratorNormalCompletion2 = true;
              var _didIteratorError2 = false;
              var _iteratorError2 = void 0;
              try {
                for (var _iterator2 = alphabet[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
                  var symbol = _step2.value;
                  var onSymbol = [];
                  updateAcceptingStates(states);
                  var _iteratorNormalCompletion3 = true;
                  var _didIteratorError3 = false;
                  var _iteratorError3 = void 0;
                  try {
                    for (var _iterator3 = states[Symbol.iterator](), _step3; !(_iteratorNormalCompletion3 = (_step3 = _iterator3.next()).done); _iteratorNormalCompletion3 = true) {
                      var state = _step3.value;
                      var nfaStatesOnSymbol = nfaTable[state][symbol];
                      if (!nfaStatesOnSymbol) {
                        continue;
                      }
                      var _iteratorNormalCompletion4 = true;
                      var _didIteratorError4 = false;
                      var _iteratorError4 = void 0;
                      try {
                        for (var _iterator4 = nfaStatesOnSymbol[Symbol.iterator](), _step4; !(_iteratorNormalCompletion4 = (_step4 = _iterator4.next()).done); _iteratorNormalCompletion4 = true) {
                          var nfaStateOnSymbol = _step4.value;
                          if (!nfaTable[nfaStateOnSymbol]) {
                            continue;
                          }
                          onSymbol.push.apply(onSymbol, _toConsumableArray(nfaTable[nfaStateOnSymbol][EPSILON_CLOSURE]));
                        }
                      } catch (err) {
                        _didIteratorError4 = true;
                        _iteratorError4 = err;
                      } finally {
                        try {
                          if (!_iteratorNormalCompletion4 && _iterator4.return) {
                            _iterator4.return();
                          }
                        } finally {
                          if (_didIteratorError4) {
                            throw _iteratorError4;
                          }
                        }
                      }
                    }
                  } catch (err) {
                    _didIteratorError3 = true;
                    _iteratorError3 = err;
                  } finally {
                    try {
                      if (!_iteratorNormalCompletion3 && _iterator3.return) {
                        _iterator3.return();
                      }
                    } finally {
                      if (_didIteratorError3) {
                        throw _iteratorError3;
                      }
                    }
                  }
                  var dfaStatesOnSymbolSet = new Set(onSymbol);
                  var dfaStatesOnSymbol = [].concat(_toConsumableArray(dfaStatesOnSymbolSet));
                  if (dfaStatesOnSymbol.length > 0) {
                    var dfaOnSymbolStr = dfaStatesOnSymbol.join(",");
                    dfaTable[dfaStateLabel][symbol] = dfaOnSymbolStr;
                    if (!dfaTable.hasOwnProperty(dfaOnSymbolStr)) {
                      worklist.unshift(dfaStatesOnSymbol);
                    }
                  }
                }
              } catch (err) {
                _didIteratorError2 = true;
                _iteratorError2 = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion2 && _iterator2.return) {
                    _iterator2.return();
                  }
                } finally {
                  if (_didIteratorError2) {
                    throw _iteratorError2;
                  }
                }
              }
            }
            return this._transitionTable = this._remapStateNumbers(dfaTable);
          }
          /**
           * Remaps state numbers in the resulting table:
           * combined states '1,2,3' -> 1, '3,4' -> 2, etc.
           */
        }, {
          key: "_remapStateNumbers",
          value: function _remapStateNumbers(calculatedDFATable) {
            var newStatesMap = {};
            this._originalTransitionTable = calculatedDFATable;
            var transitionTable = {};
            Object.keys(calculatedDFATable).forEach(function(originalNumber2, newNumber) {
              newStatesMap[originalNumber2] = newNumber + 1;
            });
            for (var originalNumber in calculatedDFATable) {
              var originalRow = calculatedDFATable[originalNumber];
              var row = {};
              for (var symbol in originalRow) {
                row[symbol] = newStatesMap[originalRow[symbol]];
              }
              transitionTable[newStatesMap[originalNumber]] = row;
            }
            this._originalAcceptingStateNumbers = this._acceptingStateNumbers;
            this._acceptingStateNumbers = /* @__PURE__ */ new Set();
            var _iteratorNormalCompletion5 = true;
            var _didIteratorError5 = false;
            var _iteratorError5 = void 0;
            try {
              for (var _iterator5 = this._originalAcceptingStateNumbers[Symbol.iterator](), _step5; !(_iteratorNormalCompletion5 = (_step5 = _iterator5.next()).done); _iteratorNormalCompletion5 = true) {
                var _originalNumber = _step5.value;
                this._acceptingStateNumbers.add(newStatesMap[_originalNumber]);
              }
            } catch (err) {
              _didIteratorError5 = true;
              _iteratorError5 = err;
            } finally {
              try {
                if (!_iteratorNormalCompletion5 && _iterator5.return) {
                  _iterator5.return();
                }
              } finally {
                if (_didIteratorError5) {
                  throw _iteratorError5;
                }
              }
            }
            return transitionTable;
          }
          /**
           * Returns original DFA table, where state numbers
           * are combined numbers from NFA.
           */
        }, {
          key: "getOriginalTransitionTable",
          value: function getOriginalTransitionTable() {
            if (!this._originalTransitionTable) {
              this.getTransitionTable();
            }
            return this._originalTransitionTable;
          }
          /**
           * Checks whether this DFA accepts a string.
           */
        }, {
          key: "matches",
          value: function matches(string) {
            var state = 1;
            var i = 0;
            var table = this.getTransitionTable();
            while (string[i]) {
              state = table[state][string[i++]];
              if (!state) {
                return false;
              }
            }
            if (!this.getAcceptingStateNumbers().has(state)) {
              return false;
            }
            return true;
          }
        }]);
        return DFA2;
      })();
      module.exports = DFA;
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/state.js
  var require_state = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/state.js"(exports, module) {
      "use strict";
      var _createClass = /* @__PURE__ */ (function() {
        function defineProperties(target, props) {
          for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
          }
        }
        return function(Constructor, protoProps, staticProps) {
          if (protoProps) defineProperties(Constructor.prototype, protoProps);
          if (staticProps) defineProperties(Constructor, staticProps);
          return Constructor;
        };
      })();
      function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
          throw new TypeError("Cannot call a class as a function");
        }
      }
      var State = (function() {
        function State2() {
          var _ref = arguments.length > 0 && arguments[0] !== void 0 ? arguments[0] : {}, _ref$accepting = _ref.accepting, accepting = _ref$accepting === void 0 ? false : _ref$accepting;
          _classCallCheck(this, State2);
          this._transitions = /* @__PURE__ */ new Map();
          this.accepting = accepting;
        }
        _createClass(State2, [{
          key: "getTransitions",
          value: function getTransitions() {
            return this._transitions;
          }
          /**
           * Creates a transition on symbol.
           */
        }, {
          key: "addTransition",
          value: function addTransition(symbol, toState) {
            this.getTransitionsOnSymbol(symbol).add(toState);
            return this;
          }
          /**
           * Returns transitions set on symbol.
           */
        }, {
          key: "getTransitionsOnSymbol",
          value: function getTransitionsOnSymbol(symbol) {
            var transitions = this._transitions.get(symbol);
            if (!transitions) {
              transitions = /* @__PURE__ */ new Set();
              this._transitions.set(symbol, transitions);
            }
            return transitions;
          }
        }]);
        return State2;
      })();
      module.exports = State;
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/nfa-state.js
  var require_nfa_state = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/nfa-state.js"(exports, module) {
      "use strict";
      var _createClass = /* @__PURE__ */ (function() {
        function defineProperties(target, props) {
          for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
          }
        }
        return function(Constructor, protoProps, staticProps) {
          if (protoProps) defineProperties(Constructor.prototype, protoProps);
          if (staticProps) defineProperties(Constructor, staticProps);
          return Constructor;
        };
      })();
      function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
          throw new TypeError("Cannot call a class as a function");
        }
      }
      function _possibleConstructorReturn(self2, call) {
        if (!self2) {
          throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
        }
        return call && (typeof call === "object" || typeof call === "function") ? call : self2;
      }
      function _inherits(subClass, superClass) {
        if (typeof superClass !== "function" && superClass !== null) {
          throw new TypeError("Super expression must either be null or a function, not " + typeof superClass);
        }
        subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } });
        if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass;
      }
      var State = require_state();
      var _require = require_special_symbols();
      var EPSILON = _require.EPSILON;
      var NFAState = (function(_State) {
        _inherits(NFAState2, _State);
        function NFAState2() {
          _classCallCheck(this, NFAState2);
          return _possibleConstructorReturn(this, (NFAState2.__proto__ || Object.getPrototypeOf(NFAState2)).apply(this, arguments));
        }
        _createClass(NFAState2, [{
          key: "matches",
          /**
           * Whether this state matches a string.
           *
           * We maintain set of visited epsilon-states to avoid infinite loops
           * when an epsilon-transition goes eventually to itself.
           *
           * NOTE: this function is rather "educational", since we use DFA for strings
           * matching. DFA is built on top of NFA, and uses fast transition table.
           */
          value: function matches(string) {
            var visited = arguments.length > 1 && arguments[1] !== void 0 ? arguments[1] : /* @__PURE__ */ new Set();
            if (visited.has(this)) {
              return false;
            }
            visited.add(this);
            if (string.length === 0) {
              if (this.accepting) {
                return true;
              }
              var _iteratorNormalCompletion = true;
              var _didIteratorError = false;
              var _iteratorError = void 0;
              try {
                for (var _iterator = this.getTransitionsOnSymbol(EPSILON)[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
                  var nextState = _step.value;
                  if (nextState.matches("", visited)) {
                    return true;
                  }
                }
              } catch (err) {
                _didIteratorError = true;
                _iteratorError = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion && _iterator.return) {
                    _iterator.return();
                  }
                } finally {
                  if (_didIteratorError) {
                    throw _iteratorError;
                  }
                }
              }
              return false;
            }
            var symbol = string[0];
            var rest = string.slice(1);
            var symbolTransitions = this.getTransitionsOnSymbol(symbol);
            var _iteratorNormalCompletion2 = true;
            var _didIteratorError2 = false;
            var _iteratorError2 = void 0;
            try {
              for (var _iterator2 = symbolTransitions[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
                var _nextState = _step2.value;
                if (_nextState.matches(rest)) {
                  return true;
                }
              }
            } catch (err) {
              _didIteratorError2 = true;
              _iteratorError2 = err;
            } finally {
              try {
                if (!_iteratorNormalCompletion2 && _iterator2.return) {
                  _iterator2.return();
                }
              } finally {
                if (_didIteratorError2) {
                  throw _iteratorError2;
                }
              }
            }
            var _iteratorNormalCompletion3 = true;
            var _didIteratorError3 = false;
            var _iteratorError3 = void 0;
            try {
              for (var _iterator3 = this.getTransitionsOnSymbol(EPSILON)[Symbol.iterator](), _step3; !(_iteratorNormalCompletion3 = (_step3 = _iterator3.next()).done); _iteratorNormalCompletion3 = true) {
                var _nextState2 = _step3.value;
                if (_nextState2.matches(string, visited)) {
                  return true;
                }
              }
            } catch (err) {
              _didIteratorError3 = true;
              _iteratorError3 = err;
            } finally {
              try {
                if (!_iteratorNormalCompletion3 && _iterator3.return) {
                  _iterator3.return();
                }
              } finally {
                if (_didIteratorError3) {
                  throw _iteratorError3;
                }
              }
            }
            return false;
          }
          /**
           * Returns an ε-closure for this state:
           * self + all states following ε-transitions.
           */
        }, {
          key: "getEpsilonClosure",
          value: function getEpsilonClosure() {
            var _this2 = this;
            if (!this._epsilonClosure) {
              (function() {
                var epsilonTransitions = _this2.getTransitionsOnSymbol(EPSILON);
                var closure = _this2._epsilonClosure = /* @__PURE__ */ new Set();
                closure.add(_this2);
                var _iteratorNormalCompletion4 = true;
                var _didIteratorError4 = false;
                var _iteratorError4 = void 0;
                try {
                  for (var _iterator4 = epsilonTransitions[Symbol.iterator](), _step4; !(_iteratorNormalCompletion4 = (_step4 = _iterator4.next()).done); _iteratorNormalCompletion4 = true) {
                    var nextState = _step4.value;
                    if (!closure.has(nextState)) {
                      closure.add(nextState);
                      var nextClosure = nextState.getEpsilonClosure();
                      nextClosure.forEach(function(state) {
                        return closure.add(state);
                      });
                    }
                  }
                } catch (err) {
                  _didIteratorError4 = true;
                  _iteratorError4 = err;
                } finally {
                  try {
                    if (!_iteratorNormalCompletion4 && _iterator4.return) {
                      _iterator4.return();
                    }
                  } finally {
                    if (_didIteratorError4) {
                      throw _iteratorError4;
                    }
                  }
                }
              })();
            }
            return this._epsilonClosure;
          }
        }]);
        return NFAState2;
      })(State);
      module.exports = NFAState;
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/builders.js
  var require_builders = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/builders.js"(exports, module) {
      "use strict";
      var NFA = require_nfa();
      var NFAState = require_nfa_state();
      var _require = require_special_symbols();
      var EPSILON = _require.EPSILON;
      function char(c) {
        var inState = new NFAState();
        var outState = new NFAState({
          accepting: true
        });
        return new NFA(inState.addTransition(c, outState), outState);
      }
      function e() {
        return char(EPSILON);
      }
      function altPair(first, second) {
        first.out.accepting = false;
        second.out.accepting = true;
        first.out.addTransition(EPSILON, second.in);
        return new NFA(first.in, second.out);
      }
      function alt(first) {
        for (var _len = arguments.length, fragments = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
          fragments[_key - 1] = arguments[_key];
        }
        var _iteratorNormalCompletion = true;
        var _didIteratorError = false;
        var _iteratorError = void 0;
        try {
          for (var _iterator = fragments[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
            var fragment = _step.value;
            first = altPair(first, fragment);
          }
        } catch (err) {
          _didIteratorError = true;
          _iteratorError = err;
        } finally {
          try {
            if (!_iteratorNormalCompletion && _iterator.return) {
              _iterator.return();
            }
          } finally {
            if (_didIteratorError) {
              throw _iteratorError;
            }
          }
        }
        return first;
      }
      function orPair(first, second) {
        var inState = new NFAState();
        var outState = new NFAState();
        inState.addTransition(EPSILON, first.in);
        inState.addTransition(EPSILON, second.in);
        outState.accepting = true;
        first.out.accepting = false;
        second.out.accepting = false;
        first.out.addTransition(EPSILON, outState);
        second.out.addTransition(EPSILON, outState);
        return new NFA(inState, outState);
      }
      function or(first) {
        for (var _len2 = arguments.length, fragments = Array(_len2 > 1 ? _len2 - 1 : 0), _key2 = 1; _key2 < _len2; _key2++) {
          fragments[_key2 - 1] = arguments[_key2];
        }
        var _iteratorNormalCompletion2 = true;
        var _didIteratorError2 = false;
        var _iteratorError2 = void 0;
        try {
          for (var _iterator2 = fragments[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
            var fragment = _step2.value;
            first = orPair(first, fragment);
          }
        } catch (err) {
          _didIteratorError2 = true;
          _iteratorError2 = err;
        } finally {
          try {
            if (!_iteratorNormalCompletion2 && _iterator2.return) {
              _iterator2.return();
            }
          } finally {
            if (_didIteratorError2) {
              throw _iteratorError2;
            }
          }
        }
        return first;
      }
      function repExplicit(fragment) {
        var inState = new NFAState();
        var outState = new NFAState({
          accepting: true
        });
        inState.addTransition(EPSILON, fragment.in);
        inState.addTransition(EPSILON, outState);
        fragment.out.accepting = false;
        fragment.out.addTransition(EPSILON, outState);
        outState.addTransition(EPSILON, fragment.in);
        return new NFA(inState, outState);
      }
      function rep(fragment) {
        fragment.in.addTransition(EPSILON, fragment.out);
        fragment.out.addTransition(EPSILON, fragment.in);
        return fragment;
      }
      function plusRep(fragment) {
        fragment.out.addTransition(EPSILON, fragment.in);
        return fragment;
      }
      function questionRep(fragment) {
        fragment.in.addTransition(EPSILON, fragment.out);
        return fragment;
      }
      module.exports = {
        alt,
        char,
        e,
        or,
        rep,
        repExplicit,
        plusRep,
        questionRep
      };
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/nfa-from-regexp.js
  var require_nfa_from_regexp = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/nfa/nfa-from-regexp.js"(exports, module) {
      "use strict";
      function _toConsumableArray(arr) {
        if (Array.isArray(arr)) {
          for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
            arr2[i] = arr[i];
          }
          return arr2;
        } else {
          return Array.from(arr);
        }
      }
      var parser = require_parser();
      var _require = require_builders();
      var alt = _require.alt;
      var char = _require.char;
      var or = _require.or;
      var rep = _require.rep;
      var plusRep = _require.plusRep;
      var questionRep = _require.questionRep;
      function gen(node) {
        if (node && !generator[node.type]) {
          throw new Error(node.type + " is not supported in NFA/DFA interpreter.");
        }
        return node ? generator[node.type](node) : "";
      }
      var generator = {
        RegExp: function RegExp2(node) {
          if (node.flags !== "") {
            throw new Error("NFA/DFA: Flags are not supported yet.");
          }
          return gen(node.body);
        },
        Alternative: function Alternative(node) {
          var fragments = (node.expressions || []).map(gen);
          return alt.apply(void 0, _toConsumableArray(fragments));
        },
        Disjunction: function Disjunction(node) {
          return or(gen(node.left), gen(node.right));
        },
        Repetition: function Repetition(node) {
          switch (node.quantifier.kind) {
            case "*":
              return rep(gen(node.expression));
            case "+":
              return plusRep(gen(node.expression));
            case "?":
              return questionRep(gen(node.expression));
            default:
              throw new Error("Unknown repeatition: " + node.quantifier.kind + ".");
          }
        },
        Char: function Char(node) {
          if (node.kind !== "simple") {
            throw new Error("NFA/DFA: Only simple chars are supported yet.");
          }
          return char(node.value);
        },
        Group: function Group3(node) {
          return gen(node.expression);
        }
      };
      module.exports = {
        /**
         * Builds an NFA from the passed regexp.
         */
        build: function build(regexp) {
          var ast = regexp;
          if (regexp instanceof RegExp) {
            regexp = "" + regexp;
          }
          if (typeof regexp === "string") {
            ast = parser.parse(regexp, {
              captureLocations: true
            });
          }
          return gen(ast);
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/interpreter/finite-automaton/index.js
  var require_finite_automaton = __commonJS({
    "node_modules/regexp-tree/dist/interpreter/finite-automaton/index.js"(exports, module) {
      "use strict";
      var NFA = require_nfa();
      var DFA = require_dfa();
      var nfaFromRegExp = require_nfa_from_regexp();
      var builders = require_builders();
      module.exports = {
        /**
         * Export NFA and DFA classes.
         */
        NFA,
        DFA,
        /**
         * Expose builders.
         */
        builders,
        /**
         * Builds an NFA for the passed regexp.
         *
         * @param string | AST | RegExp:
         *
         *   a regular expression in different representations: a string,
         *   a RegExp object, or an AST.
         */
        toNFA: function toNFA(regexp) {
          return nfaFromRegExp.build(regexp);
        },
        /**
         * Builds DFA for the passed regexp.
         *
         * @param string | AST | RegExp:
         *
         *   a regular expression in different representations: a string,
         *   a RegExp object, or an AST.
         */
        toDFA: function toDFA(regexp) {
          return new DFA(this.toNFA(regexp));
        },
        /**
         * Returns true if regexp accepts the string.
         */
        test: function test(regexp, string) {
          return this.toDFA(regexp).matches(string);
        }
      };
    }
  });

  // node_modules/regexp-tree/dist/compat-transpiler/runtime/index.js
  var require_runtime = __commonJS({
    "node_modules/regexp-tree/dist/compat-transpiler/runtime/index.js"(exports, module) {
      "use strict";
      var _createClass = /* @__PURE__ */ (function() {
        function defineProperties(target, props) {
          for (var i = 0; i < props.length; i++) {
            var descriptor = props[i];
            descriptor.enumerable = descriptor.enumerable || false;
            descriptor.configurable = true;
            if ("value" in descriptor) descriptor.writable = true;
            Object.defineProperty(target, descriptor.key, descriptor);
          }
        }
        return function(Constructor, protoProps, staticProps) {
          if (protoProps) defineProperties(Constructor.prototype, protoProps);
          if (staticProps) defineProperties(Constructor, staticProps);
          return Constructor;
        };
      })();
      function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
          throw new TypeError("Cannot call a class as a function");
        }
      }
      var RegExpTree = (function() {
        function RegExpTree2(re, _ref) {
          var flags = _ref.flags, groups = _ref.groups, source = _ref.source;
          _classCallCheck(this, RegExpTree2);
          this._re = re;
          this._groups = groups;
          this.flags = flags;
          this.source = source || re.source;
          this.dotAll = flags.includes("s");
          this.global = re.global;
          this.ignoreCase = re.ignoreCase;
          this.multiline = re.multiline;
          this.sticky = re.sticky;
          this.unicode = re.unicode;
        }
        _createClass(RegExpTree2, [{
          key: "test",
          value: function test(string) {
            return this._re.test(string);
          }
          /**
           * Facade wrapper for RegExp `compile` method.
           */
        }, {
          key: "compile",
          value: function compile2(string) {
            return this._re.compile(string);
          }
          /**
           * Facade wrapper for RegExp `toString` method.
           */
        }, {
          key: "toString",
          value: function toString() {
            if (!this._toStringResult) {
              this._toStringResult = "/" + this.source + "/" + this.flags;
            }
            return this._toStringResult;
          }
          /**
           * Facade wrapper for RegExp `exec` method.
           */
        }, {
          key: "exec",
          value: function exec(string) {
            var result = this._re.exec(string);
            if (!this._groups || !result) {
              return result;
            }
            result.groups = {};
            for (var group in this._groups) {
              var groupNumber = this._groups[group];
              result.groups[group] = result[groupNumber];
            }
            return result;
          }
        }]);
        return RegExpTree2;
      })();
      module.exports = {
        RegExpTree
      };
    }
  });

  // node_modules/regexp-tree/dist/regexp-tree.js
  var require_regexp_tree2 = __commonJS({
    "node_modules/regexp-tree/dist/regexp-tree.js"(exports, module) {
      "use strict";
      var compatTranspiler = require_compat_transpiler();
      var generator = require_generator();
      var optimizer = require_optimizer();
      var parser = require_parser();
      var _transform = require_transform();
      var _traverse = require_traverse();
      var fa = require_finite_automaton();
      var _require = require_runtime();
      var RegExpTree = _require.RegExpTree;
      var regexpTree = {
        /**
         * Parser module exposed.
         */
        parser,
        /**
         * Expose finite-automaton module.
         */
        fa,
        /**
         * `TransformResult` exposed.
         */
        TransformResult: _transform.TransformResult,
        /**
         * Parses a regexp string, producing an AST.
         *
         * @param string regexp
         *
         *   a regular expression in different formats: string, AST, RegExp.
         *
         * @param Object options
         *
         *   parsing options for this parse call. Default are:
         *
         *     - captureLocations: boolean
         *     - any other custom options
         *
         * @return Object AST
         */
        parse: function parse3(regexp, options) {
          return parser.parse("" + regexp, options);
        },
        /**
         * Traverses a RegExp AST.
         *
         * @param Object ast
         * @param Object | Array<Object> handlers
         *
         * Each `handler` is an object containing handler function for needed
         * node types. Example:
         *
         *   regexpTree.traverse(ast, {
         *     onChar(node) {
         *       ...
         *     },
         *   });
         *
         * The value for a node type may also be an object with functions pre and post.
         * This enables more context-aware analyses, e.g. measuring star height.
         */
        traverse: function traverse(ast, handlers, options) {
          return _traverse.traverse(ast, handlers, options);
        },
        /**
         * Transforms a regular expression.
         *
         * A regexp can be passed in different formats (string, regexp or AST),
         * applying a set of transformations. It is a convenient wrapper
         * on top of "parse-traverse-generate" tool chain.
         *
         * @param string | AST | RegExp regexp - a regular expression;
         * @param Object | Array<Object> handlers - a list of handlers.
         *
         * @return TransformResult - a transformation result.
         */
        transform: function transform(regexp, handlers) {
          return _transform.transform(regexp, handlers);
        },
        /**
         * Generates a RegExp string from an AST.
         *
         * @param Object ast
         *
         * Invariant:
         *
         *   regexpTree.generate(regexpTree.parse('/[a-z]+/i')); // '/[a-z]+/i'
         */
        generate: function generate(ast) {
          return generator.generate(ast);
        },
        /**
         * Creates a RegExp object from a regexp string.
         *
         * @param string regexp
         */
        toRegExp: function toRegExp(regexp) {
          var compat = this.compatTranspile(regexp);
          return new RegExp(compat.getSource(), compat.getFlags());
        },
        /**
         * Optimizes a regular expression by replacing some
         * sub-expressions with their idiomatic patterns.
         *
         * @param string regexp
         *
         * @return TransformResult object
         */
        optimize: function optimize(regexp, whitelist) {
          var _ref = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : {}, blacklist = _ref.blacklist;
          return optimizer.optimize(regexp, { whitelist, blacklist });
        },
        /**
         * Translates a regular expression in new syntax or in new format
         * into equivalent expressions in old syntax.
         *
         * @param string regexp
         *
         * @return TransformResult object
         */
        compatTranspile: function compatTranspile(regexp, whitelist) {
          return compatTranspiler.transform(regexp, whitelist);
        },
        /**
         * Executes a regular expression on a string.
         *
         * @param RegExp|string re - a regular expression.
         * @param string string - a testing string.
         */
        exec: function exec(re, string) {
          if (typeof re === "string") {
            var compat = this.compatTranspile(re);
            var extra = compat.getExtra();
            if (extra.namedCapturingGroups) {
              re = new RegExpTree(compat.toRegExp(), {
                flags: compat.getFlags(),
                source: compat.getSource(),
                groups: extra.namedCapturingGroups
              });
            } else {
              re = compat.toRegExp();
            }
          }
          return re.exec(string);
        }
      };
      module.exports = regexpTree;
    }
  });

  // node_modules/regexp-tree/index.js
  var require_regexp_tree3 = __commonJS({
    "node_modules/regexp-tree/index.js"(exports, module) {
      "use strict";
      module.exports = require_regexp_tree2();
    }
  });

  // node_modules/regexp-match-indices/implementation.js
  var require_implementation = __commonJS({
    "node_modules/regexp-match-indices/implementation.js"(exports, module) {
      "use strict";
      var config = require_config();
      var nativeExec = require_native();
      var regexp_tree_1 = require_regexp_tree3();
      var weakMeasurementRegExp = /* @__PURE__ */ new WeakMap();
      function exec(string) {
        return config.mode === "spec-compliant" ? execSpecCompliant(this, string) : execLazy(this, string);
      }
      function execLazy(regexp, string) {
        const index = regexp.lastIndex;
        const result = nativeExec.call(regexp, string);
        if (result === null)
          return null;
        let indicesArray;
        Object.defineProperty(result, "indices", {
          enumerable: true,
          configurable: true,
          get() {
            if (indicesArray === void 0) {
              const { measurementRegExp, groupInfos } = getMeasurementRegExp(regexp);
              measurementRegExp.lastIndex = index;
              const measuredResult = nativeExec.call(measurementRegExp, string);
              if (measuredResult === null)
                throw new TypeError();
              makeDataProperty(result, "indices", indicesArray = makeIndicesArray(measuredResult, groupInfos));
            }
            return indicesArray;
          },
          set(value) {
            makeDataProperty(result, "indices", value);
          }
        });
        return result;
      }
      function execSpecCompliant(regexp, string) {
        const { measurementRegExp, groupInfos } = getMeasurementRegExp(regexp);
        measurementRegExp.lastIndex = regexp.lastIndex;
        const measuredResult = nativeExec.call(measurementRegExp, string);
        if (measuredResult === null)
          return null;
        regexp.lastIndex = measurementRegExp.lastIndex;
        const result = [];
        makeDataProperty(result, 0, measuredResult[0]);
        for (const groupInfo of groupInfos) {
          makeDataProperty(result, groupInfo.oldGroupNumber, measuredResult[groupInfo.newGroupNumber]);
        }
        makeDataProperty(result, "index", measuredResult.index);
        makeDataProperty(result, "input", measuredResult.input);
        makeDataProperty(result, "groups", measuredResult.groups);
        makeDataProperty(result, "indices", makeIndicesArray(measuredResult, groupInfos));
        return result;
      }
      function getMeasurementRegExp(regexp) {
        let transformed = weakMeasurementRegExp.get(regexp);
        if (!transformed) {
          transformed = transformMeasurementGroups(regexp_tree_1.parse(`/${regexp.source}/${regexp.flags}`));
          weakMeasurementRegExp.set(regexp, transformed);
        }
        const groupInfos = transformed.getExtra();
        const measurementRegExp = transformed.toRegExp();
        return { measurementRegExp, groupInfos };
      }
      function makeIndicesArray(measuredResult, groupInfos) {
        const matchStart = measuredResult.index;
        const matchEnd = matchStart + measuredResult[0].length;
        const hasGroups = !!measuredResult.groups;
        const indicesArray = [];
        const groups = hasGroups ? /* @__PURE__ */ Object.create(null) : void 0;
        makeDataProperty(indicesArray, 0, [matchStart, matchEnd]);
        for (const groupInfo of groupInfos) {
          let indices;
          if (measuredResult[groupInfo.newGroupNumber] !== void 0) {
            let startIndex = matchStart;
            if (groupInfo.measurementGroups) {
              for (const measurementGroup of groupInfo.measurementGroups) {
                startIndex += measuredResult[measurementGroup].length;
              }
            }
            const endIndex = startIndex + measuredResult[groupInfo.newGroupNumber].length;
            indices = [startIndex, endIndex];
          }
          makeDataProperty(indicesArray, groupInfo.oldGroupNumber, indices);
          if (groups && groupInfo.groupName !== void 0) {
            makeDataProperty(groups, groupInfo.groupName, indices);
          }
        }
        makeDataProperty(indicesArray, "groups", groups);
        return indicesArray;
      }
      function makeDataProperty(result, key, value) {
        const existingDesc = Object.getOwnPropertyDescriptor(result, key);
        if (existingDesc ? existingDesc.configurable : Object.isExtensible(result)) {
          const newDesc = {
            enumerable: existingDesc ? existingDesc.enumerable : true,
            configurable: existingDesc ? existingDesc.configurable : true,
            writable: true,
            value
          };
          Object.defineProperty(result, key, newDesc);
        }
      }
      var groupRenumbers;
      var hasBackreferences = false;
      var nodesContainingCapturingGroup = /* @__PURE__ */ new Set();
      var containsCapturingGroupStack = [];
      var containsCapturingGroup = false;
      var nextNewGroupNumber = 1;
      var measurementGroupStack = [];
      var measurementGroupsForGroup = /* @__PURE__ */ new Map();
      var newGroupNumberForGroup = /* @__PURE__ */ new Map();
      var handlers = {
        init() {
          hasBackreferences = false;
          nodesContainingCapturingGroup.clear();
          containsCapturingGroupStack.length = 0;
          containsCapturingGroup = false;
          nextNewGroupNumber = 1;
          measurementGroupStack.length = 0;
          measurementGroupsForGroup.clear();
          newGroupNumberForGroup.clear();
          groupRenumbers = [];
        },
        RegExp(path) {
          regexp_tree_1.traverse(path.node, visitor);
          if (nodesContainingCapturingGroup.size > 0) {
            regexp_tree_1.transform(path.node, builder);
            regexp_tree_1.transform(path.node, groupRenumberer);
            if (hasBackreferences) {
              regexp_tree_1.transform(path.node, backreferenceRenumberer);
            }
          }
          return false;
        }
      };
      var nodeCallbacks = {
        pre(path) {
          containsCapturingGroupStack.push(containsCapturingGroup);
          containsCapturingGroup = path.node.type === "Group" && path.node.capturing;
        },
        post(path) {
          if (containsCapturingGroup) {
            nodesContainingCapturingGroup.add(path.node);
          }
          containsCapturingGroup = containsCapturingGroupStack.pop() || containsCapturingGroup;
        }
      };
      var visitor = {
        Alternative: nodeCallbacks,
        Disjunction: nodeCallbacks,
        Assertion: nodeCallbacks,
        Group: nodeCallbacks,
        Repetition: nodeCallbacks,
        Backreference(path) {
          hasBackreferences = true;
        }
      };
      var builder = {
        Alternative(path) {
          if (nodesContainingCapturingGroup.has(path.node)) {
            let lastMeasurementIndex = 0;
            let pendingTerms = [];
            const measurementGroups = [];
            const terms = [];
            for (let i = 0; i < path.node.expressions.length; i++) {
              const term = path.node.expressions[i];
              if (nodesContainingCapturingGroup.has(term)) {
                if (i > lastMeasurementIndex) {
                  const measurementGroup = {
                    type: "Group",
                    capturing: true,
                    number: -1,
                    expression: pendingTerms.length > 1 ? { type: "Alternative", expressions: pendingTerms } : pendingTerms.length === 1 ? pendingTerms[0] : null
                  };
                  terms.push(measurementGroup);
                  measurementGroups.push(measurementGroup);
                  lastMeasurementIndex = i;
                  pendingTerms = [];
                }
                measurementGroupStack.push(measurementGroups);
                regexp_tree_1.transform(term, builder);
                measurementGroupStack.pop();
                pendingTerms.push(term);
                continue;
              }
              pendingTerms.push(term);
            }
            path.update({ expressions: terms.concat(pendingTerms) });
          }
          return false;
        },
        Group(path) {
          if (!path.node.capturing)
            return;
          measurementGroupsForGroup.set(path.node, getMeasurementGroups());
        }
      };
      var groupRenumberer = {
        Group(path) {
          if (!groupRenumbers)
            throw new Error("Not initialized.");
          if (!path.node.capturing)
            return;
          const oldGroupNumber = path.node.number;
          const newGroupNumber = nextNewGroupNumber++;
          const measurementGroups = measurementGroupsForGroup.get(path.node);
          if (oldGroupNumber !== -1) {
            groupRenumbers.push({
              oldGroupNumber,
              newGroupNumber,
              measurementGroups: measurementGroups && measurementGroups.map((group) => group.number),
              groupName: path.node.name
            });
            newGroupNumberForGroup.set(oldGroupNumber, newGroupNumber);
          }
          path.update({ number: newGroupNumber });
        }
      };
      var backreferenceRenumberer = {
        Backreference(path) {
          const newGroupNumber = newGroupNumberForGroup.get(path.node.number);
          if (newGroupNumber) {
            if (path.node.kind === "number") {
              path.update({
                number: newGroupNumber,
                reference: newGroupNumber
              });
            } else {
              path.update({
                number: newGroupNumber
              });
            }
          }
        }
      };
      function getMeasurementGroups() {
        const measurementGroups = [];
        for (const array of measurementGroupStack) {
          for (const item of array) {
            measurementGroups.push(item);
          }
        }
        return measurementGroups;
      }
      function transformMeasurementGroups(ast) {
        const result = regexp_tree_1.transform(ast, handlers);
        return new regexp_tree_1.TransformResult(result.getAST(), groupRenumbers);
      }
      module.exports = exec;
    }
  });

  // node_modules/regexp-match-indices/polyfill.js
  var require_polyfill = __commonJS({
    "node_modules/regexp-match-indices/polyfill.js"(exports, module) {
      "use strict";
      var nativeExec = require_native();
      var implementation = require_implementation();
      function getPolyfill() {
        const re = new RegExp("a");
        const match = nativeExec.call(re, "a");
        if (match.indices) {
          return nativeExec;
        }
        return implementation;
      }
      module.exports = getPolyfill;
    }
  });

  // node_modules/regexp-match-indices/shim.js
  var require_shim = __commonJS({
    "node_modules/regexp-match-indices/shim.js"(exports, module) {
      "use strict";
      var getPolyfill = require_polyfill();
      function shim() {
        const polyfill = getPolyfill();
        if (RegExp.prototype.exec !== polyfill) {
          RegExp.prototype.exec = polyfill;
        }
      }
      module.exports = shim;
    }
  });

  // node_modules/regexp-match-indices/index.js
  var require_regexp_match_indices = __commonJS({
    "node_modules/regexp-match-indices/index.js"(exports, module) {
      "use strict";
      var implementation = require_implementation();
      var native = require_native();
      var getPolyfill = require_polyfill();
      var shim = require_shim();
      var config = require_config();
      var polyfill = getPolyfill();
      function exec(regexp, string) {
        return polyfill.call(regexp, string);
      }
      exec.implementation = implementation;
      exec.native = native;
      exec.getPolyfill = getPolyfill;
      exec.shim = shim;
      exec.config = config;
      /* @__PURE__ */ (function(exec2) {
      })(exec || (exec = {}));
      module.exports = exec;
    }
  });

  // parser/core.js
  var import_gherkin = __toESM(require_src2(), 1);

  // node_modules/@cucumber/messages/dist/esm/src/IdGenerator.js
  var IdGenerator_exports = {};
  __export(IdGenerator_exports, {
    incrementing: () => incrementing,
    uuid: () => uuid
  });

  // node_modules/uuid/dist/esm/stringify.js
  var byteToHex2 = [];
  for (let i = 0; i < 256; ++i) {
    byteToHex2.push((i + 256).toString(16).slice(1));
  }
  function unsafeStringify2(arr, offset = 0) {
    return (byteToHex2[arr[offset + 0]] + byteToHex2[arr[offset + 1]] + byteToHex2[arr[offset + 2]] + byteToHex2[arr[offset + 3]] + "-" + byteToHex2[arr[offset + 4]] + byteToHex2[arr[offset + 5]] + "-" + byteToHex2[arr[offset + 6]] + byteToHex2[arr[offset + 7]] + "-" + byteToHex2[arr[offset + 8]] + byteToHex2[arr[offset + 9]] + "-" + byteToHex2[arr[offset + 10]] + byteToHex2[arr[offset + 11]] + byteToHex2[arr[offset + 12]] + byteToHex2[arr[offset + 13]] + byteToHex2[arr[offset + 14]] + byteToHex2[arr[offset + 15]]).toLowerCase();
  }

  // node_modules/uuid/dist/esm/rng.js
  var import_crypto = __require("crypto");
  var rnds8Pool2 = new Uint8Array(256);
  var poolPtr2 = rnds8Pool2.length;
  function rng2() {
    if (poolPtr2 > rnds8Pool2.length - 16) {
      (0, import_crypto.randomFillSync)(rnds8Pool2);
      poolPtr2 = 0;
    }
    return rnds8Pool2.slice(poolPtr2, poolPtr2 += 16);
  }

  // node_modules/uuid/dist/esm/native.js
  var import_crypto2 = __require("crypto");
  var native_default2 = { randomUUID: import_crypto2.randomUUID };

  // node_modules/uuid/dist/esm/v4.js
  function v42(options, buf, offset) {
    var _a;
    if (native_default2.randomUUID && !buf && !options) {
      return native_default2.randomUUID();
    }
    options = options || {};
    const rnds = options.random ?? ((_a = options.rng) == null ? void 0 : _a.call(options)) ?? rng2();
    if (rnds.length < 16) {
      throw new Error("Random bytes length must be >= 16");
    }
    rnds[6] = rnds[6] & 15 | 64;
    rnds[8] = rnds[8] & 63 | 128;
    if (buf) {
      offset = offset || 0;
      if (offset < 0 || offset + 16 > buf.length) {
        throw new RangeError(`UUID byte range ${offset}:${offset + 15} is out of buffer bounds`);
      }
      for (let i = 0; i < 16; ++i) {
        buf[offset + i] = rnds[i];
      }
      return buf;
    }
    return unsafeStringify2(rnds);
  }
  var v4_default2 = v42;

  // node_modules/@cucumber/messages/dist/esm/src/IdGenerator.js
  function uuid() {
    return () => v4_default2();
  }
  function incrementing() {
    let next = 0;
    return () => (next++).toString();
  }

  // node_modules/@cucumber/messages/dist/esm/src/messages.js
  var import_class_transformer = __toESM(require_cjs(), 1);
  var import_reflect_metadata = __toESM(require_Reflect(), 1);
  var __decorate = function(decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
  };
  var Attachment = class {
    constructor() {
      this.body = "";
      this.contentEncoding = AttachmentContentEncoding.IDENTITY;
      this.mediaType = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Source)
  ], Attachment.prototype, "source", void 0);
  var Duration = class {
    constructor() {
      this.seconds = 0;
      this.nanos = 0;
    }
  };
  var Envelope = class {
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Attachment)
  ], Envelope.prototype, "attachment", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => GherkinDocument)
  ], Envelope.prototype, "gherkinDocument", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Hook)
  ], Envelope.prototype, "hook", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Meta)
  ], Envelope.prototype, "meta", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => ParameterType)
  ], Envelope.prototype, "parameterType", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => ParseError)
  ], Envelope.prototype, "parseError", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Pickle)
  ], Envelope.prototype, "pickle", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Source)
  ], Envelope.prototype, "source", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => StepDefinition)
  ], Envelope.prototype, "stepDefinition", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestCase)
  ], Envelope.prototype, "testCase", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestCaseFinished)
  ], Envelope.prototype, "testCaseFinished", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestCaseStarted)
  ], Envelope.prototype, "testCaseStarted", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestRunFinished)
  ], Envelope.prototype, "testRunFinished", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestRunStarted)
  ], Envelope.prototype, "testRunStarted", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestStepFinished)
  ], Envelope.prototype, "testStepFinished", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestStepStarted)
  ], Envelope.prototype, "testStepStarted", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestRunHookStarted)
  ], Envelope.prototype, "testRunHookStarted", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TestRunHookFinished)
  ], Envelope.prototype, "testRunHookFinished", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => UndefinedParameterType)
  ], Envelope.prototype, "undefinedParameterType", void 0);
  var Exception = class {
    constructor() {
      this.type = "";
    }
  };
  var GherkinDocument = class {
    constructor() {
      this.comments = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Feature)
  ], GherkinDocument.prototype, "feature", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Comment)
  ], GherkinDocument.prototype, "comments", void 0);
  var Background = class {
    constructor() {
      this.location = new Location();
      this.keyword = "";
      this.name = "";
      this.description = "";
      this.steps = [];
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Background.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Step)
  ], Background.prototype, "steps", void 0);
  var Comment = class {
    constructor() {
      this.location = new Location();
      this.text = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Comment.prototype, "location", void 0);
  var DataTable = class {
    constructor() {
      this.location = new Location();
      this.rows = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], DataTable.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TableRow)
  ], DataTable.prototype, "rows", void 0);
  var DocString = class {
    constructor() {
      this.location = new Location();
      this.content = "";
      this.delimiter = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], DocString.prototype, "location", void 0);
  var Examples = class {
    constructor() {
      this.location = new Location();
      this.tags = [];
      this.keyword = "";
      this.name = "";
      this.description = "";
      this.tableBody = [];
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Examples.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Tag)
  ], Examples.prototype, "tags", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TableRow)
  ], Examples.prototype, "tableHeader", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TableRow)
  ], Examples.prototype, "tableBody", void 0);
  var Feature = class {
    constructor() {
      this.location = new Location();
      this.tags = [];
      this.language = "";
      this.keyword = "";
      this.name = "";
      this.description = "";
      this.children = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Feature.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Tag)
  ], Feature.prototype, "tags", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => FeatureChild)
  ], Feature.prototype, "children", void 0);
  var FeatureChild = class {
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Rule)
  ], FeatureChild.prototype, "rule", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Background)
  ], FeatureChild.prototype, "background", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Scenario)
  ], FeatureChild.prototype, "scenario", void 0);
  var Rule = class {
    constructor() {
      this.location = new Location();
      this.tags = [];
      this.keyword = "";
      this.name = "";
      this.description = "";
      this.children = [];
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Rule.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Tag)
  ], Rule.prototype, "tags", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => RuleChild)
  ], Rule.prototype, "children", void 0);
  var RuleChild = class {
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Background)
  ], RuleChild.prototype, "background", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Scenario)
  ], RuleChild.prototype, "scenario", void 0);
  var Scenario = class {
    constructor() {
      this.location = new Location();
      this.tags = [];
      this.keyword = "";
      this.name = "";
      this.description = "";
      this.steps = [];
      this.examples = [];
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Scenario.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Tag)
  ], Scenario.prototype, "tags", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Step)
  ], Scenario.prototype, "steps", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Examples)
  ], Scenario.prototype, "examples", void 0);
  var Step = class {
    constructor() {
      this.location = new Location();
      this.keyword = "";
      this.text = "";
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Step.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => DocString)
  ], Step.prototype, "docString", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => DataTable)
  ], Step.prototype, "dataTable", void 0);
  var TableCell = class {
    constructor() {
      this.location = new Location();
      this.value = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], TableCell.prototype, "location", void 0);
  var TableRow = class {
    constructor() {
      this.location = new Location();
      this.cells = [];
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], TableRow.prototype, "location", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => TableCell)
  ], TableRow.prototype, "cells", void 0);
  var Tag = class {
    constructor() {
      this.location = new Location();
      this.name = "";
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], Tag.prototype, "location", void 0);
  var Hook = class {
    constructor() {
      this.id = "";
      this.sourceReference = new SourceReference();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => SourceReference)
  ], Hook.prototype, "sourceReference", void 0);
  var Location = class {
    constructor() {
      this.line = 0;
    }
  };
  var Meta = class {
    constructor() {
      this.protocolVersion = "";
      this.implementation = new Product();
      this.runtime = new Product();
      this.os = new Product();
      this.cpu = new Product();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Product)
  ], Meta.prototype, "implementation", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Product)
  ], Meta.prototype, "runtime", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Product)
  ], Meta.prototype, "os", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Product)
  ], Meta.prototype, "cpu", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Ci)
  ], Meta.prototype, "ci", void 0);
  var Ci = class {
    constructor() {
      this.name = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Git)
  ], Ci.prototype, "git", void 0);
  var Git = class {
    constructor() {
      this.remote = "";
      this.revision = "";
    }
  };
  var Product = class {
    constructor() {
      this.name = "";
    }
  };
  var ParameterType = class {
    constructor() {
      this.name = "";
      this.regularExpressions = [];
      this.preferForRegularExpressionMatch = false;
      this.useForSnippets = false;
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => SourceReference)
  ], ParameterType.prototype, "sourceReference", void 0);
  var ParseError = class {
    constructor() {
      this.source = new SourceReference();
      this.message = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => SourceReference)
  ], ParseError.prototype, "source", void 0);
  var Pickle = class {
    constructor() {
      this.id = "";
      this.uri = "";
      this.name = "";
      this.language = "";
      this.steps = [];
      this.tags = [];
      this.astNodeIds = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => PickleStep)
  ], Pickle.prototype, "steps", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => PickleTag)
  ], Pickle.prototype, "tags", void 0);
  var PickleDocString = class {
    constructor() {
      this.content = "";
    }
  };
  var PickleStep = class {
    constructor() {
      this.astNodeIds = [];
      this.id = "";
      this.text = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => PickleStepArgument)
  ], PickleStep.prototype, "argument", void 0);
  var PickleStepArgument = class {
  };
  __decorate([
    (0, import_class_transformer.Type)(() => PickleDocString)
  ], PickleStepArgument.prototype, "docString", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => PickleTable)
  ], PickleStepArgument.prototype, "dataTable", void 0);
  var PickleTable = class {
    constructor() {
      this.rows = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => PickleTableRow)
  ], PickleTable.prototype, "rows", void 0);
  var PickleTableCell = class {
    constructor() {
      this.value = "";
    }
  };
  var PickleTableRow = class {
    constructor() {
      this.cells = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => PickleTableCell)
  ], PickleTableRow.prototype, "cells", void 0);
  var PickleTag = class {
    constructor() {
      this.name = "";
      this.astNodeId = "";
    }
  };
  var Source = class {
    constructor() {
      this.uri = "";
      this.data = "";
      this.mediaType = SourceMediaType.TEXT_X_CUCUMBER_GHERKIN_PLAIN;
    }
  };
  var SourceReference = class {
  };
  __decorate([
    (0, import_class_transformer.Type)(() => JavaMethod)
  ], SourceReference.prototype, "javaMethod", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => JavaStackTraceElement)
  ], SourceReference.prototype, "javaStackTraceElement", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Location)
  ], SourceReference.prototype, "location", void 0);
  var JavaMethod = class {
    constructor() {
      this.className = "";
      this.methodName = "";
      this.methodParameterTypes = [];
    }
  };
  var JavaStackTraceElement = class {
    constructor() {
      this.className = "";
      this.fileName = "";
      this.methodName = "";
    }
  };
  var StepDefinition = class {
    constructor() {
      this.id = "";
      this.pattern = new StepDefinitionPattern();
      this.sourceReference = new SourceReference();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => StepDefinitionPattern)
  ], StepDefinition.prototype, "pattern", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => SourceReference)
  ], StepDefinition.prototype, "sourceReference", void 0);
  var StepDefinitionPattern = class {
    constructor() {
      this.source = "";
      this.type = StepDefinitionPatternType.CUCUMBER_EXPRESSION;
    }
  };
  var TestCase = class {
    constructor() {
      this.id = "";
      this.pickleId = "";
      this.testSteps = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => TestStep)
  ], TestCase.prototype, "testSteps", void 0);
  var Group = class {
    constructor() {
      this.children = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Group)
  ], Group.prototype, "children", void 0);
  var StepMatchArgument = class {
    constructor() {
      this.group = new Group();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Group)
  ], StepMatchArgument.prototype, "group", void 0);
  var StepMatchArgumentsList = class {
    constructor() {
      this.stepMatchArguments = [];
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => StepMatchArgument)
  ], StepMatchArgumentsList.prototype, "stepMatchArguments", void 0);
  var TestStep = class {
    constructor() {
      this.id = "";
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => StepMatchArgumentsList)
  ], TestStep.prototype, "stepMatchArgumentsLists", void 0);
  var TestCaseFinished = class {
    constructor() {
      this.testCaseStartedId = "";
      this.timestamp = new Timestamp();
      this.willBeRetried = false;
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestCaseFinished.prototype, "timestamp", void 0);
  var TestCaseStarted = class {
    constructor() {
      this.attempt = 0;
      this.id = "";
      this.testCaseId = "";
      this.timestamp = new Timestamp();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestCaseStarted.prototype, "timestamp", void 0);
  var TestRunFinished = class {
    constructor() {
      this.success = false;
      this.timestamp = new Timestamp();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestRunFinished.prototype, "timestamp", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Exception)
  ], TestRunFinished.prototype, "exception", void 0);
  var TestRunHookFinished = class {
    constructor() {
      this.testRunHookStartedId = "";
      this.result = new TestStepResult();
      this.timestamp = new Timestamp();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => TestStepResult)
  ], TestRunHookFinished.prototype, "result", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestRunHookFinished.prototype, "timestamp", void 0);
  var TestRunHookStarted = class {
    constructor() {
      this.id = "";
      this.testRunStartedId = "";
      this.hookId = "";
      this.timestamp = new Timestamp();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestRunHookStarted.prototype, "timestamp", void 0);
  var TestRunStarted = class {
    constructor() {
      this.timestamp = new Timestamp();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestRunStarted.prototype, "timestamp", void 0);
  var TestStepFinished = class {
    constructor() {
      this.testCaseStartedId = "";
      this.testStepId = "";
      this.testStepResult = new TestStepResult();
      this.timestamp = new Timestamp();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => TestStepResult)
  ], TestStepFinished.prototype, "testStepResult", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestStepFinished.prototype, "timestamp", void 0);
  var TestStepResult = class {
    constructor() {
      this.duration = new Duration();
      this.status = TestStepResultStatus.UNKNOWN;
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Duration)
  ], TestStepResult.prototype, "duration", void 0);
  __decorate([
    (0, import_class_transformer.Type)(() => Exception)
  ], TestStepResult.prototype, "exception", void 0);
  var TestStepStarted = class {
    constructor() {
      this.testCaseStartedId = "";
      this.testStepId = "";
      this.timestamp = new Timestamp();
    }
  };
  __decorate([
    (0, import_class_transformer.Type)(() => Timestamp)
  ], TestStepStarted.prototype, "timestamp", void 0);
  var Timestamp = class {
    constructor() {
      this.seconds = 0;
      this.nanos = 0;
    }
  };
  var UndefinedParameterType = class {
    constructor() {
      this.expression = "";
      this.name = "";
    }
  };
  var AttachmentContentEncoding;
  (function(AttachmentContentEncoding2) {
    AttachmentContentEncoding2["IDENTITY"] = "IDENTITY";
    AttachmentContentEncoding2["BASE64"] = "BASE64";
  })(AttachmentContentEncoding || (AttachmentContentEncoding = {}));
  var HookType;
  (function(HookType2) {
    HookType2["BEFORE_TEST_RUN"] = "BEFORE_TEST_RUN";
    HookType2["AFTER_TEST_RUN"] = "AFTER_TEST_RUN";
    HookType2["BEFORE_TEST_CASE"] = "BEFORE_TEST_CASE";
    HookType2["AFTER_TEST_CASE"] = "AFTER_TEST_CASE";
    HookType2["BEFORE_TEST_STEP"] = "BEFORE_TEST_STEP";
    HookType2["AFTER_TEST_STEP"] = "AFTER_TEST_STEP";
  })(HookType || (HookType = {}));
  var PickleStepType;
  (function(PickleStepType2) {
    PickleStepType2["UNKNOWN"] = "Unknown";
    PickleStepType2["CONTEXT"] = "Context";
    PickleStepType2["ACTION"] = "Action";
    PickleStepType2["OUTCOME"] = "Outcome";
  })(PickleStepType || (PickleStepType = {}));
  var SourceMediaType;
  (function(SourceMediaType2) {
    SourceMediaType2["TEXT_X_CUCUMBER_GHERKIN_PLAIN"] = "text/x.cucumber.gherkin+plain";
    SourceMediaType2["TEXT_X_CUCUMBER_GHERKIN_MARKDOWN"] = "text/x.cucumber.gherkin+markdown";
  })(SourceMediaType || (SourceMediaType = {}));
  var StepDefinitionPatternType;
  (function(StepDefinitionPatternType2) {
    StepDefinitionPatternType2["CUCUMBER_EXPRESSION"] = "CUCUMBER_EXPRESSION";
    StepDefinitionPatternType2["REGULAR_EXPRESSION"] = "REGULAR_EXPRESSION";
  })(StepDefinitionPatternType || (StepDefinitionPatternType = {}));
  var StepKeywordType;
  (function(StepKeywordType2) {
    StepKeywordType2["UNKNOWN"] = "Unknown";
    StepKeywordType2["CONTEXT"] = "Context";
    StepKeywordType2["ACTION"] = "Action";
    StepKeywordType2["OUTCOME"] = "Outcome";
    StepKeywordType2["CONJUNCTION"] = "Conjunction";
  })(StepKeywordType || (StepKeywordType = {}));
  var TestStepResultStatus;
  (function(TestStepResultStatus2) {
    TestStepResultStatus2["UNKNOWN"] = "UNKNOWN";
    TestStepResultStatus2["PASSED"] = "PASSED";
    TestStepResultStatus2["SKIPPED"] = "SKIPPED";
    TestStepResultStatus2["PENDING"] = "PENDING";
    TestStepResultStatus2["UNDEFINED"] = "UNDEFINED";
    TestStepResultStatus2["AMBIGUOUS"] = "AMBIGUOUS";
    TestStepResultStatus2["FAILED"] = "FAILED";
  })(TestStepResultStatus || (TestStepResultStatus = {}));

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/CucumberExpressionError.js
  var CucumberExpressionError = class extends Error {
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/Argument.js
  var Argument = class _Argument {
    group;
    parameterType;
    static build(group, parameterTypes) {
      const argGroups = group.children;
      if (argGroups.length !== parameterTypes.length) {
        throw new CucumberExpressionError(`Group has ${argGroups.length} capture groups (${argGroups.map((g) => g.value)}), but there were ${parameterTypes.length} parameter types (${parameterTypes.map((p) => p.name)})`);
      }
      return parameterTypes.map((parameterType, i) => new _Argument(argGroups[i], parameterType));
    }
    constructor(group, parameterType) {
      this.group = group;
      this.parameterType = parameterType;
      this.group = group;
      this.parameterType = parameterType;
    }
    /**
     * Get the value returned by the parameter type's transformer function.
     *
     * @param thisObj the object in which the transformer function is applied.
     */
    getValue(thisObj) {
      const groupValues = this.group ? this.group.values : null;
      return this.parameterType.transform(thisObj, groupValues);
    }
    getParameterType() {
      return this.parameterType;
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/Ast.js
  var escapeCharacter = "\\";
  var alternationCharacter = "/";
  var beginParameterCharacter = "{";
  var endParameterCharacter = "}";
  var beginOptionalCharacter = "(";
  var endOptionalCharacter = ")";
  function symbolOf(token) {
    switch (token) {
      case TokenType.beginOptional:
        return beginOptionalCharacter;
      case TokenType.endOptional:
        return endOptionalCharacter;
      case TokenType.beginParameter:
        return beginParameterCharacter;
      case TokenType.endParameter:
        return endParameterCharacter;
      case TokenType.alternation:
        return alternationCharacter;
    }
    return "";
  }
  function purposeOf(token) {
    switch (token) {
      case TokenType.beginOptional:
      case TokenType.endOptional:
        return "optional text";
      case TokenType.beginParameter:
      case TokenType.endParameter:
        return "a parameter";
      case TokenType.alternation:
        return "alternation";
    }
    return "";
  }
  var Node = class {
    type;
    nodes;
    token;
    start;
    end;
    constructor(type, nodes, token, start, end) {
      this.type = type;
      this.nodes = nodes;
      this.token = token;
      this.start = start;
      this.end = end;
      if (nodes === void 0 && token === void 0) {
        throw new Error("Either nodes or token must be defined");
      }
    }
    text() {
      if (this.nodes && this.nodes.length > 0) {
        return this.nodes.map((value) => value.text()).join("");
      }
      return this.token || "";
    }
  };
  var NodeType;
  (function(NodeType2) {
    NodeType2["text"] = "TEXT_NODE";
    NodeType2["optional"] = "OPTIONAL_NODE";
    NodeType2["alternation"] = "ALTERNATION_NODE";
    NodeType2["alternative"] = "ALTERNATIVE_NODE";
    NodeType2["parameter"] = "PARAMETER_NODE";
    NodeType2["expression"] = "EXPRESSION_NODE";
  })(NodeType || (NodeType = {}));
  var Token = class {
    type;
    text;
    start;
    end;
    constructor(type, text, start, end) {
      this.type = type;
      this.text = text;
      this.start = start;
      this.end = end;
    }
    static isEscapeCharacter(codePoint) {
      return codePoint == escapeCharacter;
    }
    static canEscape(codePoint) {
      if (codePoint == " ") {
        return true;
      }
      switch (codePoint) {
        case escapeCharacter:
          return true;
        case alternationCharacter:
          return true;
        case beginParameterCharacter:
          return true;
        case endParameterCharacter:
          return true;
        case beginOptionalCharacter:
          return true;
        case endOptionalCharacter:
          return true;
      }
      return false;
    }
    static typeOf(codePoint) {
      if (codePoint == " ") {
        return TokenType.whiteSpace;
      }
      switch (codePoint) {
        case alternationCharacter:
          return TokenType.alternation;
        case beginParameterCharacter:
          return TokenType.beginParameter;
        case endParameterCharacter:
          return TokenType.endParameter;
        case beginOptionalCharacter:
          return TokenType.beginOptional;
        case endOptionalCharacter:
          return TokenType.endOptional;
      }
      return TokenType.text;
    }
  };
  var TokenType;
  (function(TokenType2) {
    TokenType2["startOfLine"] = "START_OF_LINE";
    TokenType2["endOfLine"] = "END_OF_LINE";
    TokenType2["whiteSpace"] = "WHITE_SPACE";
    TokenType2["beginOptional"] = "BEGIN_OPTIONAL";
    TokenType2["endOptional"] = "END_OPTIONAL";
    TokenType2["beginParameter"] = "BEGIN_PARAMETER";
    TokenType2["endParameter"] = "END_PARAMETER";
    TokenType2["alternation"] = "ALTERNATION";
    TokenType2["text"] = "TEXT";
  })(TokenType || (TokenType = {}));

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/Errors.js
  function createAlternativeMayNotExclusivelyContainOptionals(node, expression) {
    return new CucumberExpressionError(message(node.start, expression, pointAtLocated(node), "An alternative may not exclusively contain optionals", "If you did not mean to use an optional you can use '\\(' to escape the '('"));
  }
  function createAlternativeMayNotBeEmpty(node, expression) {
    return new CucumberExpressionError(message(node.start, expression, pointAtLocated(node), "Alternative may not be empty", "If you did not mean to use an alternative you can use '\\/' to escape the '/'"));
  }
  function createOptionalMayNotBeEmpty(node, expression) {
    return new CucumberExpressionError(message(node.start, expression, pointAtLocated(node), "An optional must contain some text", "If you did not mean to use an optional you can use '\\(' to escape the '('"));
  }
  function createParameterIsNotAllowedInOptional(node, expression) {
    return new CucumberExpressionError(message(node.start, expression, pointAtLocated(node), "An optional may not contain a parameter type", "If you did not mean to use an parameter type you can use '\\{' to escape the '{'"));
  }
  function createOptionalIsNotAllowedInOptional(node, expression) {
    return new CucumberExpressionError(message(node.start, expression, pointAtLocated(node), "An optional may not contain an other optional", "If you did not mean to use an optional type you can use '\\(' to escape the '('. For more complicated expressions consider using a regular expression instead."));
  }
  function createTheEndOfLIneCanNotBeEscaped(expression) {
    const index = Array.from(expression).length - 1;
    return new CucumberExpressionError(message(index, expression, pointAt(index), "The end of line can not be escaped", "You can use '\\\\' to escape the '\\'"));
  }
  function createMissingEndToken(expression, beginToken, endToken, current) {
    const beginSymbol = symbolOf(beginToken);
    const endSymbol = symbolOf(endToken);
    const purpose = purposeOf(beginToken);
    return new CucumberExpressionError(message(current.start, expression, pointAtLocated(current), `The '${beginSymbol}' does not have a matching '${endSymbol}'`, `If you did not intend to use ${purpose} you can use '\\${beginSymbol}' to escape the ${purpose}`));
  }
  function createAlternationNotAllowedInOptional(expression, current) {
    return new CucumberExpressionError(message(current.start, expression, pointAtLocated(current), "An alternation can not be used inside an optional", "If you did not mean to use an alternation you can use '\\/' to escape the '/'. Otherwise rephrase your expression or consider using a regular expression instead."));
  }
  function createCantEscaped(expression, index) {
    return new CucumberExpressionError(message(index, expression, pointAt(index), "Only the characters '{', '}', '(', ')', '\\', '/' and whitespace can be escaped", "If you did mean to use an '\\' you can use '\\\\' to escape it"));
  }
  function createInvalidParameterTypeNameInNode(token, expression) {
    return new CucumberExpressionError(message(token.start, expression, pointAtLocated(token), "Parameter names may not contain '{', '}', '(', ')', '\\' or '/'", "Did you mean to use a regular expression?"));
  }
  function message(index, expression, pointer, problem, solution) {
    return `This Cucumber Expression has a problem at column ${index + 1}:

${expression}
${pointer}
${problem}.
${solution}`;
  }
  function pointAt(index) {
    const pointer = [];
    for (let i = 0; i < index; i++) {
      pointer.push(" ");
    }
    pointer.push("^");
    return pointer.join("");
  }
  function pointAtLocated(node) {
    const pointer = [pointAt(node.start)];
    if (node.start + 1 < node.end) {
      for (let i = node.start + 1; i < node.end - 1; i++) {
        pointer.push("-");
      }
      pointer.push("^");
    }
    return pointer.join("");
  }
  var AmbiguousParameterTypeError = class extends CucumberExpressionError {
    static forRegExp(parameterTypeRegexp, expressionRegexp, parameterTypes, generatedExpressions) {
      return new this(`Your Regular Expression ${expressionRegexp}
matches multiple parameter types with regexp ${parameterTypeRegexp}:
   ${this._parameterTypeNames(parameterTypes)}

I couldn't decide which one to use. You have two options:

1) Use a Cucumber Expression instead of a Regular Expression. Try one of these:
   ${this._expressions(generatedExpressions)}

2) Make one of the parameter types preferential and continue to use a Regular Expression.
`);
    }
    static _parameterTypeNames(parameterTypes) {
      return parameterTypes.map((p) => `{${p.name}}`).join("\n   ");
    }
    static _expressions(generatedExpressions) {
      return generatedExpressions.map((e) => e.source).join("\n   ");
    }
  };
  var UndefinedParameterTypeError = class extends CucumberExpressionError {
    undefinedParameterTypeName;
    constructor(undefinedParameterTypeName, message2) {
      super(message2);
      this.undefinedParameterTypeName = undefinedParameterTypeName;
    }
  };
  function createUndefinedParameterType(node, expression, undefinedParameterTypeName) {
    return new UndefinedParameterTypeError(undefinedParameterTypeName, message(node.start, expression, pointAtLocated(node), `Undefined parameter type '${undefinedParameterTypeName}'`, `Please register a ParameterType for '${undefinedParameterTypeName}'`));
  }

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/CucumberExpressionTokenizer.js
  var CucumberExpressionTokenizer = class {
    tokenize(expression) {
      const codePoints = Array.from(expression);
      const tokens = [];
      let buffer = [];
      let previousTokenType = TokenType.startOfLine;
      let treatAsText = false;
      let escaped = 0;
      let bufferStartIndex = 0;
      function convertBufferToToken(tokenType) {
        let escapeTokens = 0;
        if (tokenType == TokenType.text) {
          escapeTokens = escaped;
          escaped = 0;
        }
        const consumedIndex = bufferStartIndex + buffer.length + escapeTokens;
        const t = new Token(tokenType, buffer.join(""), bufferStartIndex, consumedIndex);
        buffer = [];
        bufferStartIndex = consumedIndex;
        return t;
      }
      function tokenTypeOf(codePoint, treatAsText2) {
        if (!treatAsText2) {
          return Token.typeOf(codePoint);
        }
        if (Token.canEscape(codePoint)) {
          return TokenType.text;
        }
        throw createCantEscaped(expression, bufferStartIndex + buffer.length + escaped);
      }
      function shouldCreateNewToken(previousTokenType2, currentTokenType) {
        if (currentTokenType != previousTokenType2) {
          return true;
        }
        return currentTokenType != TokenType.whiteSpace && currentTokenType != TokenType.text;
      }
      if (codePoints.length == 0) {
        tokens.push(new Token(TokenType.startOfLine, "", 0, 0));
      }
      codePoints.forEach((codePoint) => {
        if (!treatAsText && Token.isEscapeCharacter(codePoint)) {
          escaped++;
          treatAsText = true;
          return;
        }
        const currentTokenType = tokenTypeOf(codePoint, treatAsText);
        treatAsText = false;
        if (shouldCreateNewToken(previousTokenType, currentTokenType)) {
          const token = convertBufferToToken(previousTokenType);
          previousTokenType = currentTokenType;
          buffer.push(codePoint);
          tokens.push(token);
        } else {
          previousTokenType = currentTokenType;
          buffer.push(codePoint);
        }
      });
      if (buffer.length > 0) {
        const token = convertBufferToToken(previousTokenType);
        tokens.push(token);
      }
      if (treatAsText) {
        throw createTheEndOfLIneCanNotBeEscaped(expression);
      }
      tokens.push(new Token(TokenType.endOfLine, "", codePoints.length, codePoints.length));
      return tokens;
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/CucumberExpressionParser.js
  function parseText(expression, tokens, current) {
    const token = tokens[current];
    switch (token.type) {
      case TokenType.whiteSpace:
      case TokenType.text:
      case TokenType.endParameter:
      case TokenType.endOptional:
        return {
          consumed: 1,
          ast: [new Node(NodeType.text, void 0, token.text, token.start, token.end)]
        };
      case TokenType.alternation:
        throw createAlternationNotAllowedInOptional(expression, token);
      case TokenType.startOfLine:
      case TokenType.endOfLine:
      case TokenType.beginOptional:
      case TokenType.beginParameter:
      default:
        return { consumed: 0, ast: [] };
    }
  }
  function parseName(expression, tokens, current) {
    const token = tokens[current];
    switch (token.type) {
      case TokenType.whiteSpace:
      case TokenType.text:
        return {
          consumed: 1,
          ast: [new Node(NodeType.text, void 0, token.text, token.start, token.end)]
        };
      case TokenType.beginOptional:
      case TokenType.endOptional:
      case TokenType.beginParameter:
      case TokenType.endParameter:
      case TokenType.alternation:
        throw createInvalidParameterTypeNameInNode(token, expression);
      case TokenType.startOfLine:
      case TokenType.endOfLine:
      default:
        return { consumed: 0, ast: [] };
    }
  }
  var parseParameter = parseBetween(NodeType.parameter, TokenType.beginParameter, TokenType.endParameter, [parseName]);
  var optionalSubParsers = [];
  var parseOptional = parseBetween(NodeType.optional, TokenType.beginOptional, TokenType.endOptional, optionalSubParsers);
  optionalSubParsers.push(parseOptional, parseParameter, parseText);
  function parseAlternativeSeparator(expression, tokens, current) {
    if (!lookingAt(tokens, current, TokenType.alternation)) {
      return { consumed: 0, ast: [] };
    }
    const token = tokens[current];
    return {
      consumed: 1,
      ast: [new Node(NodeType.alternative, void 0, token.text, token.start, token.end)]
    };
  }
  var alternativeParsers = [
    parseAlternativeSeparator,
    parseOptional,
    parseParameter,
    parseText
  ];
  var parseAlternation = (expression, tokens, current) => {
    const previous = current - 1;
    if (!lookingAtAny(tokens, previous, [
      TokenType.startOfLine,
      TokenType.whiteSpace,
      TokenType.endParameter
    ])) {
      return { consumed: 0, ast: [] };
    }
    const result = parseTokensUntil(expression, alternativeParsers, tokens, current, [
      TokenType.whiteSpace,
      TokenType.endOfLine,
      TokenType.beginParameter
    ]);
    const subCurrent = current + result.consumed;
    if (!result.ast.some((astNode) => astNode.type == NodeType.alternative)) {
      return { consumed: 0, ast: [] };
    }
    const start = tokens[current].start;
    const end = tokens[subCurrent].start;
    return {
      consumed: result.consumed,
      ast: [
        new Node(NodeType.alternation, splitAlternatives(start, end, result.ast), void 0, start, end)
      ]
    };
  };
  var parseCucumberExpression = parseBetween(NodeType.expression, TokenType.startOfLine, TokenType.endOfLine, [parseAlternation, parseOptional, parseParameter, parseText]);
  var CucumberExpressionParser = class {
    parse(expression) {
      const tokenizer = new CucumberExpressionTokenizer();
      const tokens = tokenizer.tokenize(expression);
      const result = parseCucumberExpression(expression, tokens, 0);
      return result.ast[0];
    }
  };
  function parseBetween(type, beginToken, endToken, parsers) {
    return (expression, tokens, current) => {
      if (!lookingAt(tokens, current, beginToken)) {
        return { consumed: 0, ast: [] };
      }
      let subCurrent = current + 1;
      const result = parseTokensUntil(expression, parsers, tokens, subCurrent, [
        endToken,
        TokenType.endOfLine
      ]);
      subCurrent += result.consumed;
      if (!lookingAt(tokens, subCurrent, endToken)) {
        throw createMissingEndToken(expression, beginToken, endToken, tokens[current]);
      }
      const start = tokens[current].start;
      const end = tokens[subCurrent].end;
      const consumed = subCurrent + 1 - current;
      const ast = [new Node(type, result.ast, void 0, start, end)];
      return { consumed, ast };
    };
  }
  function parseToken(expression, parsers, tokens, startAt) {
    for (let i = 0; i < parsers.length; i++) {
      const parse3 = parsers[i];
      const result = parse3(expression, tokens, startAt);
      if (result.consumed != 0) {
        return result;
      }
    }
    throw new Error("No eligible parsers for " + tokens);
  }
  function parseTokensUntil(expression, parsers, tokens, startAt, endTokens) {
    let current = startAt;
    const size = tokens.length;
    const ast = [];
    while (current < size) {
      if (lookingAtAny(tokens, current, endTokens)) {
        break;
      }
      const result = parseToken(expression, parsers, tokens, current);
      if (result.consumed == 0) {
        throw new Error("No eligible parsers for " + tokens);
      }
      current += result.consumed;
      ast.push(...result.ast);
    }
    return { consumed: current - startAt, ast };
  }
  function lookingAtAny(tokens, at, tokenTypes) {
    return tokenTypes.some((tokenType) => lookingAt(tokens, at, tokenType));
  }
  function lookingAt(tokens, at, token) {
    if (at < 0) {
      return token == TokenType.startOfLine;
    }
    if (at >= tokens.length) {
      return token == TokenType.endOfLine;
    }
    return tokens[at].type == token;
  }
  function splitAlternatives(start, end, alternation) {
    const separators = [];
    const alternatives = [];
    let alternative = [];
    alternation.forEach((n) => {
      if (NodeType.alternative == n.type) {
        separators.push(n);
        alternatives.push(alternative);
        alternative = [];
      } else {
        alternative.push(n);
      }
    });
    alternatives.push(alternative);
    return createAlternativeNodes(start, end, separators, alternatives);
  }
  function createAlternativeNodes(start, end, separators, alternatives) {
    const nodes = [];
    for (let i = 0; i < alternatives.length; i++) {
      const n = alternatives[i];
      if (i == 0) {
        const rightSeparator = separators[i];
        nodes.push(new Node(NodeType.alternative, n, void 0, start, rightSeparator.start));
      } else if (i == alternatives.length - 1) {
        const leftSeparator = separators[i - 1];
        nodes.push(new Node(NodeType.alternative, n, void 0, leftSeparator.end, end));
      } else {
        const leftSeparator = separators[i - 1];
        const rightSeparator = separators[i];
        nodes.push(new Node(NodeType.alternative, n, void 0, leftSeparator.end, rightSeparator.start));
      }
    }
    return nodes;
  }

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/TreeRegexp.js
  var import_regexp_match_indices = __toESM(require_regexp_match_indices(), 1);

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/Group.js
  var Group2 = class {
    value;
    start;
    end;
    children;
    constructor(value, start, end, children) {
      this.value = value;
      this.start = start;
      this.end = end;
      this.children = children;
    }
    get values() {
      return (this.children.length === 0 ? [this] : this.children).map((g) => g.value);
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/GroupBuilder.js
  var GroupBuilder = class {
    source;
    capturing = true;
    groupBuilders = [];
    add(groupBuilder) {
      this.groupBuilders.push(groupBuilder);
    }
    build(match, nextGroupIndex) {
      const groupIndex = nextGroupIndex();
      const children = this.groupBuilders.map((gb) => gb.build(match, nextGroupIndex));
      const value = match[groupIndex];
      const index = match.indices[groupIndex];
      const start = index ? index[0] : void 0;
      const end = index ? index[1] : void 0;
      return new Group2(value, start, end, children);
    }
    setNonCapturing() {
      this.capturing = false;
    }
    get children() {
      return this.groupBuilders;
    }
    moveChildrenTo(groupBuilder) {
      this.groupBuilders.forEach((child) => groupBuilder.add(child));
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/TreeRegexp.js
  var TreeRegexp = class _TreeRegexp {
    regexp;
    groupBuilder;
    constructor(regexp) {
      if (regexp instanceof RegExp) {
        this.regexp = regexp;
      } else {
        this.regexp = new RegExp(regexp);
      }
      this.groupBuilder = _TreeRegexp.createGroupBuilder(this.regexp);
    }
    static createGroupBuilder(regexp) {
      const source = regexp.source;
      const stack = [new GroupBuilder()];
      const groupStartStack = [];
      let escaping = false;
      let charClass = false;
      for (let i = 0; i < source.length; i++) {
        const c = source[i];
        if (c === "[" && !escaping) {
          charClass = true;
        } else if (c === "]" && !escaping) {
          charClass = false;
        } else if (c === "(" && !escaping && !charClass) {
          groupStartStack.push(i);
          const nonCapturing = _TreeRegexp.isNonCapturing(source, i);
          const groupBuilder = new GroupBuilder();
          if (nonCapturing) {
            groupBuilder.setNonCapturing();
          }
          stack.push(groupBuilder);
        } else if (c === ")" && !escaping && !charClass) {
          const gb = stack.pop();
          if (!gb)
            throw new Error("Empty stack");
          const groupStart = groupStartStack.pop();
          if (gb.capturing) {
            gb.source = source.substring((groupStart || 0) + 1, i);
            stack[stack.length - 1].add(gb);
          } else {
            gb.moveChildrenTo(stack[stack.length - 1]);
          }
        }
        escaping = c === "\\" && !escaping;
      }
      const result = stack.pop();
      if (!result)
        throw new Error("Empty stack");
      return result;
    }
    static isNonCapturing(source, i) {
      if (source[i + 1] !== "?") {
        return false;
      }
      if (source[i + 2] !== "<") {
        return true;
      }
      return source[i + 3] === "=" || source[i + 3] === "!";
    }
    match(s) {
      const match = (0, import_regexp_match_indices.default)(this.regexp, s);
      if (!match) {
        return null;
      }
      let groupIndex = 0;
      const nextGroupIndex = () => groupIndex++;
      return this.groupBuilder.build(match, nextGroupIndex);
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/CucumberExpression.js
  var ESCAPE_PATTERN = () => /([\\^[({$.|?*+})\]])/g;
  var CucumberExpression = class _CucumberExpression {
    expression;
    parameterTypeRegistry;
    parameterTypes = [];
    treeRegexp;
    ast;
    /**
     * @param expression
     * @param parameterTypeRegistry
     */
    constructor(expression, parameterTypeRegistry) {
      this.expression = expression;
      this.parameterTypeRegistry = parameterTypeRegistry;
      const parser = new CucumberExpressionParser();
      this.ast = parser.parse(expression);
      const pattern = this.rewriteToRegex(this.ast);
      this.treeRegexp = new TreeRegexp(pattern);
    }
    rewriteToRegex(node) {
      switch (node.type) {
        case NodeType.text:
          return _CucumberExpression.escapeRegex(node.text());
        case NodeType.optional:
          return this.rewriteOptional(node);
        case NodeType.alternation:
          return this.rewriteAlternation(node);
        case NodeType.alternative:
          return this.rewriteAlternative(node);
        case NodeType.parameter:
          return this.rewriteParameter(node);
        case NodeType.expression:
          return this.rewriteExpression(node);
        default:
          throw new Error(node.type);
      }
    }
    static escapeRegex(expression) {
      return expression.replace(ESCAPE_PATTERN(), "\\$1");
    }
    rewriteOptional(node) {
      this.assertNoParameters(node, (astNode) => createParameterIsNotAllowedInOptional(astNode, this.expression));
      this.assertNoOptionals(node, (astNode) => createOptionalIsNotAllowedInOptional(astNode, this.expression));
      this.assertNotEmpty(node, (astNode) => createOptionalMayNotBeEmpty(astNode, this.expression));
      const regex = (node.nodes || []).map((node2) => this.rewriteToRegex(node2)).join("");
      return `(?:${regex})?`;
    }
    rewriteAlternation(node) {
      for (const alternative of node.nodes || []) {
        if (!alternative.nodes || alternative.nodes.length == 0) {
          throw createAlternativeMayNotBeEmpty(alternative, this.expression);
        }
        this.assertNotEmpty(alternative, (astNode) => createAlternativeMayNotExclusivelyContainOptionals(astNode, this.expression));
      }
      const regex = (node.nodes || []).map((node2) => this.rewriteToRegex(node2)).join("|");
      return `(?:${regex})`;
    }
    rewriteAlternative(node) {
      return (node.nodes || []).map((lastNode) => this.rewriteToRegex(lastNode)).join("");
    }
    rewriteParameter(node) {
      const name = node.text();
      const parameterType = this.parameterTypeRegistry.lookupByTypeName(name);
      if (!parameterType) {
        throw createUndefinedParameterType(node, this.expression, name);
      }
      this.parameterTypes.push(parameterType);
      const regexps = parameterType.regexpStrings;
      if (regexps.length == 1) {
        return `(${regexps[0]})`;
      }
      return `((?:${regexps.join(")|(?:")}))`;
    }
    rewriteExpression(node) {
      const regex = (node.nodes || []).map((node2) => this.rewriteToRegex(node2)).join("");
      return `^${regex}$`;
    }
    assertNotEmpty(node, createNodeWasNotEmptyException) {
      const textNodes = (node.nodes || []).filter((astNode) => NodeType.text == astNode.type);
      if (textNodes.length == 0) {
        throw createNodeWasNotEmptyException(node);
      }
    }
    assertNoParameters(node, createNodeContainedAParameterError) {
      const parameterNodes = (node.nodes || []).filter((astNode) => NodeType.parameter == astNode.type);
      if (parameterNodes.length > 0) {
        throw createNodeContainedAParameterError(parameterNodes[0]);
      }
    }
    assertNoOptionals(node, createNodeContainedAnOptionalError) {
      const parameterNodes = (node.nodes || []).filter((astNode) => NodeType.optional == astNode.type);
      if (parameterNodes.length > 0) {
        throw createNodeContainedAnOptionalError(parameterNodes[0]);
      }
    }
    match(text) {
      const group = this.treeRegexp.match(text);
      if (!group) {
        return null;
      }
      return Argument.build(group, this.parameterTypes);
    }
    get regexp() {
      return this.treeRegexp.regexp;
    }
    get source() {
      return this.expression;
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/GeneratedExpression.js
  var GeneratedExpression = class {
    expressionTemplate;
    parameterTypes;
    constructor(expressionTemplate, parameterTypes) {
      this.expressionTemplate = expressionTemplate;
      this.parameterTypes = parameterTypes;
    }
    get source() {
      return format(this.expressionTemplate, ...this.parameterTypes.map((t) => t.name || ""));
    }
    /**
     * Returns an array of parameter names to use in generated function/method signatures
     *
     * @returns {ReadonlyArray.<String>}
     */
    get parameterNames() {
      return this.parameterInfos.map((i) => `${i.name}${i.count === 1 ? "" : i.count.toString()}`);
    }
    /**
     * Returns an array of ParameterInfo to use in generated function/method signatures
     */
    get parameterInfos() {
      const usageByTypeName = {};
      return this.parameterTypes.map((t) => getParameterInfo(t, usageByTypeName));
    }
  };
  function getParameterInfo(parameterType, usageByName) {
    const name = parameterType.name || "";
    let counter = usageByName[name];
    counter = counter ? counter + 1 : 1;
    usageByName[name] = counter;
    let type;
    if (parameterType.type) {
      if (typeof parameterType.type === "string") {
        type = parameterType.type;
      } else if ("name" in parameterType.type) {
        type = parameterType.type.name;
      } else {
        type = null;
      }
    } else {
      type = null;
    }
    return {
      type,
      name,
      count: counter
    };
  }
  function format(pattern, ...args) {
    return pattern.replace(/{(\d+)}/g, (match, number) => args[number]);
  }

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/CombinatorialGeneratedExpressionFactory.js
  var MAX_EXPRESSIONS = 256;
  var CombinatorialGeneratedExpressionFactory = class {
    expressionTemplate;
    parameterTypeCombinations;
    constructor(expressionTemplate, parameterTypeCombinations) {
      this.expressionTemplate = expressionTemplate;
      this.parameterTypeCombinations = parameterTypeCombinations;
      this.expressionTemplate = expressionTemplate;
    }
    generateExpressions() {
      const generatedExpressions = [];
      this.generatePermutations(generatedExpressions, 0, []);
      return generatedExpressions;
    }
    generatePermutations(generatedExpressions, depth, currentParameterTypes) {
      if (generatedExpressions.length >= MAX_EXPRESSIONS) {
        return;
      }
      if (depth === this.parameterTypeCombinations.length) {
        generatedExpressions.push(new GeneratedExpression(this.expressionTemplate, currentParameterTypes));
        return;
      }
      for (let i = 0; i < this.parameterTypeCombinations[depth].length; ++i) {
        if (generatedExpressions.length >= MAX_EXPRESSIONS) {
          return;
        }
        const newCurrentParameterTypes = currentParameterTypes.slice();
        newCurrentParameterTypes.push(this.parameterTypeCombinations[depth][i]);
        this.generatePermutations(generatedExpressions, depth + 1, newCurrentParameterTypes);
      }
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/ParameterType.js
  var ILLEGAL_PARAMETER_NAME_PATTERN = /([[\]()$.|?*+])/;
  var UNESCAPE_PATTERN = () => /(\\([[$.|?*+\]]))/g;
  var ParameterType2 = class _ParameterType {
    name;
    type;
    useForSnippets;
    preferForRegexpMatch;
    builtin;
    transformFn;
    static compare(pt1, pt2) {
      if (pt1.preferForRegexpMatch && !pt2.preferForRegexpMatch) {
        return -1;
      }
      if (pt2.preferForRegexpMatch && !pt1.preferForRegexpMatch) {
        return 1;
      }
      return (pt1.name || "").localeCompare(pt2.name || "");
    }
    static checkParameterTypeName(typeName) {
      if (!this.isValidParameterTypeName(typeName)) {
        throw new CucumberExpressionError(`Illegal character in parameter name {${typeName}}. Parameter names may not contain '{', '}', '(', ')', '\\' or '/'`);
      }
    }
    static isValidParameterTypeName(typeName) {
      const unescapedTypeName = typeName.replace(UNESCAPE_PATTERN(), "$2");
      return !unescapedTypeName.match(ILLEGAL_PARAMETER_NAME_PATTERN);
    }
    regexpStrings;
    /**
     * @param name {String} the name of the type
     * @param regexps {Array.<RegExp | String>,RegExp,String} that matche the type
     * @param type {Function} the prototype (constructor) of the type. May be null.
     * @param transform {Function} function transforming string to another type. May be null.
     * @param useForSnippets {boolean} true if this should be used for snippets. Defaults to true.
     * @param preferForRegexpMatch {boolean} true if this is a preferential type. Defaults to false.
     * @param builtin whether or not this is a built-in type
     */
    constructor(name, regexps, type, transform, useForSnippets, preferForRegexpMatch, builtin) {
      this.name = name;
      this.type = type;
      this.useForSnippets = useForSnippets;
      this.preferForRegexpMatch = preferForRegexpMatch;
      this.builtin = builtin;
      if (transform === void 0) {
        transform = (s) => s;
      }
      if (useForSnippets === void 0) {
        this.useForSnippets = true;
      }
      if (preferForRegexpMatch === void 0) {
        this.preferForRegexpMatch = false;
      }
      if (name) {
        _ParameterType.checkParameterTypeName(name);
      }
      this.regexpStrings = stringArray(regexps);
      this.transformFn = transform;
    }
    transform(thisObj, groupValues) {
      return this.transformFn.apply(thisObj, groupValues);
    }
  };
  function stringArray(regexps) {
    const array = Array.isArray(regexps) ? regexps : [regexps];
    return array.map((r) => r instanceof RegExp ? regexpSource(r) : r);
  }
  function regexpSource(regexp) {
    const flags = regexpFlags(regexp);
    for (const flag of ["g", "i", "m", "y"]) {
      if (flags.indexOf(flag) !== -1) {
        throw new CucumberExpressionError(`ParameterType Regexps can't use flag '${flag}'`);
      }
    }
    return regexp.source;
  }
  function regexpFlags(regexp) {
    let flags = regexp.flags;
    if (flags === void 0) {
      flags = "";
      if (regexp.ignoreCase) {
        flags += "i";
      }
      if (regexp.global) {
        flags += "g";
      }
      if (regexp.multiline) {
        flags += "m";
      }
    }
    return flags;
  }

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/ParameterTypeMatcher.js
  var ParameterTypeMatcher = class _ParameterTypeMatcher {
    parameterType;
    regexpString;
    text;
    matchPosition;
    match;
    constructor(parameterType, regexpString, text, matchPosition = 0) {
      this.parameterType = parameterType;
      this.regexpString = regexpString;
      this.text = text;
      this.matchPosition = matchPosition;
      const captureGroupRegexp = new RegExp(`(${regexpString})`);
      this.match = captureGroupRegexp.exec(text.slice(this.matchPosition));
    }
    advanceTo(newMatchPosition) {
      for (let advancedPos = newMatchPosition; advancedPos < this.text.length; advancedPos++) {
        const matcher = new _ParameterTypeMatcher(this.parameterType, this.regexpString, this.text, advancedPos);
        if (matcher.find) {
          return matcher;
        }
      }
      return new _ParameterTypeMatcher(this.parameterType, this.regexpString, this.text, this.text.length);
    }
    get find() {
      return this.match && this.group !== "" && this.fullWord;
    }
    get start() {
      if (!this.match)
        throw new Error("No match");
      return this.matchPosition + this.match.index;
    }
    get fullWord() {
      return this.matchStartWord && this.matchEndWord;
    }
    get matchStartWord() {
      return this.start === 0 || this.text[this.start - 1].match(new RegExp("\\p{Z}|\\p{P}|\\p{S}", "u"));
    }
    get matchEndWord() {
      const nextCharacterIndex = this.start + this.group.length;
      return nextCharacterIndex === this.text.length || this.text[nextCharacterIndex].match(new RegExp("\\p{Z}|\\p{P}|\\p{S}", "u"));
    }
    get group() {
      if (!this.match)
        throw new Error("No match");
      return this.match[0];
    }
    static compare(a, b) {
      const posComparison = a.start - b.start;
      if (posComparison !== 0) {
        return posComparison;
      }
      const lengthComparison = b.group.length - a.group.length;
      if (lengthComparison !== 0) {
        return lengthComparison;
      }
      return 0;
    }
  };

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/CucumberExpressionGenerator.js
  var CucumberExpressionGenerator = class _CucumberExpressionGenerator {
    parameterTypes;
    constructor(parameterTypes) {
      this.parameterTypes = parameterTypes;
    }
    generateExpressions(text) {
      const parameterTypeCombinations = [];
      const parameterTypeMatchers = this.createParameterTypeMatchers(text);
      let expressionTemplate = "";
      let pos = 0;
      let counter = 0;
      while (true) {
        let matchingParameterTypeMatchers = [];
        for (const parameterTypeMatcher of parameterTypeMatchers) {
          const advancedParameterTypeMatcher = parameterTypeMatcher.advanceTo(pos);
          if (advancedParameterTypeMatcher.find) {
            matchingParameterTypeMatchers.push(advancedParameterTypeMatcher);
          }
        }
        if (matchingParameterTypeMatchers.length > 0) {
          matchingParameterTypeMatchers = matchingParameterTypeMatchers.sort(ParameterTypeMatcher.compare);
          const bestParameterTypeMatcher = matchingParameterTypeMatchers[0];
          const bestParameterTypeMatchers = matchingParameterTypeMatchers.filter((m) => ParameterTypeMatcher.compare(m, bestParameterTypeMatcher) === 0);
          let parameterTypes = [];
          for (const parameterTypeMatcher of bestParameterTypeMatchers) {
            if (parameterTypes.indexOf(parameterTypeMatcher.parameterType) === -1) {
              parameterTypes.push(parameterTypeMatcher.parameterType);
            }
          }
          parameterTypes = parameterTypes.sort(ParameterType2.compare);
          parameterTypeCombinations.push(parameterTypes);
          expressionTemplate += escape(text.slice(pos, bestParameterTypeMatcher.start));
          expressionTemplate += `{{${counter++}}}`;
          pos = bestParameterTypeMatcher.start + bestParameterTypeMatcher.group.length;
        } else {
          break;
        }
        if (pos >= text.length) {
          break;
        }
      }
      expressionTemplate += escape(text.slice(pos));
      return new CombinatorialGeneratedExpressionFactory(expressionTemplate, parameterTypeCombinations).generateExpressions();
    }
    createParameterTypeMatchers(text) {
      let parameterMatchers = [];
      for (const parameterType of this.parameterTypes()) {
        if (parameterType.useForSnippets) {
          parameterMatchers = parameterMatchers.concat(_CucumberExpressionGenerator.createParameterTypeMatchers2(parameterType, text));
        }
      }
      return parameterMatchers;
    }
    static createParameterTypeMatchers2(parameterType, text) {
      return parameterType.regexpStrings.map((regexp) => new ParameterTypeMatcher(parameterType, regexp, text));
    }
  };
  function escape(s) {
    return s.replace(/\(/g, "\\(").replace(/{/g, "\\{").replace(/\//g, "\\/");
  }

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/defineDefaultParameterTypes.js
  var INTEGER_REGEXPS = [/-?\d+/, /\d+/];
  var FLOAT_REGEXP = /(?=.*\d.*)[-+]?\d*(?:\.(?=\d.*))?\d*(?:\d+[E][+-]?\d+)?/;
  var WORD_REGEXP = /[^\s]+/;
  var STRING_REGEXP = /"([^"\\]*(\\.[^"\\]*)*)"|'([^'\\]*(\\.[^'\\]*)*)'/;
  var ANONYMOUS_REGEXP = /.*/;
  function defineDefaultParameterTypes(registry) {
    registry.defineParameterType(new ParameterType2("int", INTEGER_REGEXPS, Number, (s) => s === void 0 ? null : Number(s), true, true, true));
    registry.defineParameterType(new ParameterType2("float", FLOAT_REGEXP, Number, (s) => s === void 0 ? null : parseFloat(s), true, false, true));
    registry.defineParameterType(new ParameterType2("word", WORD_REGEXP, String, (s) => s, false, false, true));
    registry.defineParameterType(new ParameterType2("string", STRING_REGEXP, String, (s1, s2) => (s1 || s2 || "").replace(/\\"/g, '"').replace(/\\'/g, "'"), true, false, true));
    registry.defineParameterType(new ParameterType2("", ANONYMOUS_REGEXP, String, (s) => s, false, true, true));
    registry.defineParameterType(new ParameterType2("double", FLOAT_REGEXP, Number, (s) => s === void 0 ? null : parseFloat(s), false, false, true));
    registry.defineParameterType(new ParameterType2("bigdecimal", FLOAT_REGEXP, String, (s) => s === void 0 ? null : s, false, false, true));
    registry.defineParameterType(new ParameterType2("byte", INTEGER_REGEXPS, Number, (s) => s === void 0 ? null : Number(s), false, false, true));
    registry.defineParameterType(new ParameterType2("short", INTEGER_REGEXPS, Number, (s) => s === void 0 ? null : Number(s), false, false, true));
    registry.defineParameterType(new ParameterType2("long", INTEGER_REGEXPS, Number, (s) => s === void 0 ? null : Number(s), false, false, true));
    registry.defineParameterType(new ParameterType2("biginteger", INTEGER_REGEXPS, BigInt, (s) => s === void 0 ? null : BigInt(s), false, false, true));
  }

  // node_modules/@cucumber/cucumber-expressions/dist/esm/src/ParameterTypeRegistry.js
  var ParameterTypeRegistry = class {
    parameterTypeByName = /* @__PURE__ */ new Map();
    parameterTypesByRegexp = /* @__PURE__ */ new Map();
    constructor() {
      defineDefaultParameterTypes(this);
    }
    get parameterTypes() {
      return this.parameterTypeByName.values();
    }
    lookupByTypeName(typeName) {
      return this.parameterTypeByName.get(typeName);
    }
    lookupByRegexp(parameterTypeRegexp, expressionRegexp, text) {
      const parameterTypes = this.parameterTypesByRegexp.get(parameterTypeRegexp);
      if (!parameterTypes) {
        return void 0;
      }
      if (parameterTypes.length > 1 && !parameterTypes[0].preferForRegexpMatch) {
        const generatedExpressions = new CucumberExpressionGenerator(() => this.parameterTypes).generateExpressions(text);
        throw AmbiguousParameterTypeError.forRegExp(parameterTypeRegexp, expressionRegexp, parameterTypes, generatedExpressions);
      }
      return parameterTypes[0];
    }
    defineParameterType(parameterType) {
      if (parameterType.name !== void 0) {
        if (this.parameterTypeByName.has(parameterType.name)) {
          if (parameterType.name.length === 0) {
            throw new CucumberExpressionError(`The anonymous parameter type has already been defined`);
          } else {
            throw new CucumberExpressionError(`There is already a parameter type with name ${parameterType.name}`);
          }
        }
        this.parameterTypeByName.set(parameterType.name, parameterType);
      }
      for (const parameterTypeRegexp of parameterType.regexpStrings) {
        if (!this.parameterTypesByRegexp.has(parameterTypeRegexp)) {
          this.parameterTypesByRegexp.set(parameterTypeRegexp, []);
        }
        const parameterTypes = this.parameterTypesByRegexp.get(parameterTypeRegexp);
        const existingParameterType = parameterTypes[0];
        if (parameterTypes.length > 0 && existingParameterType.preferForRegexpMatch && parameterType.preferForRegexpMatch) {
          throw new CucumberExpressionError(`There can only be one preferential parameter type per regexp. The regexp /${parameterTypeRegexp}/ is used for two preferential parameter types, {${existingParameterType.name}} and {${parameterType.name}}`);
        }
        if (parameterTypes.indexOf(parameterType) === -1) {
          parameterTypes.push(parameterType);
          this.parameterTypesByRegexp.set(parameterTypeRegexp, parameterTypes.sort(ParameterType2.compare));
        }
      }
    }
  };

  // node_modules/@cucumber/tag-expressions/dist/esm/src/index.js
  var OPERAND = "operand";
  var OPERATOR = "operator";
  var PREC = {
    "(": -2,
    ")": -1,
    or: 0,
    and: 1,
    not: 2
  };
  var ASSOC = {
    or: "left",
    and: "left",
    not: "right"
  };
  function parse2(infix) {
    const tokens = tokenize(infix);
    if (tokens.length === 0) {
      return new True();
    }
    const expressions = [];
    const operators = [];
    let expectedTokenType = OPERAND;
    tokens.forEach(function(token) {
      if (isUnary(token)) {
        check(expectedTokenType, OPERAND);
        operators.push(token);
        expectedTokenType = OPERAND;
      } else if (isBinary(token)) {
        check(expectedTokenType, OPERATOR);
        while (operators.length > 0 && isOp(peek(operators)) && (ASSOC[token] === "left" && PREC[token] <= PREC[peek(operators)] || ASSOC[token] === "right" && PREC[token] < PREC[peek(operators)])) {
          pushExpr(pop(operators), expressions);
        }
        operators.push(token);
        expectedTokenType = OPERAND;
      } else if ("(" === token) {
        check(expectedTokenType, OPERAND);
        operators.push(token);
        expectedTokenType = OPERAND;
      } else if (")" === token) {
        check(expectedTokenType, OPERATOR);
        while (operators.length > 0 && peek(operators) !== "(") {
          pushExpr(pop(operators), expressions);
        }
        if (operators.length === 0) {
          throw new Error(`Tag expression "${infix}" could not be parsed because of syntax error: Unmatched ).`);
        }
        if (peek(operators) === "(") {
          pop(operators);
        }
        expectedTokenType = OPERATOR;
      } else {
        check(expectedTokenType, OPERAND);
        pushExpr(token, expressions);
        expectedTokenType = OPERATOR;
      }
    });
    while (operators.length > 0) {
      if (peek(operators) === "(") {
        throw new Error(`Tag expression "${infix}" could not be parsed because of syntax error: Unmatched (.`);
      }
      pushExpr(pop(operators), expressions);
    }
    return pop(expressions);
    function check(expectedTokenType2, tokenType) {
      if (expectedTokenType2 !== tokenType) {
        throw new Error(`Tag expression "${infix}" could not be parsed because of syntax error: Expected ${expectedTokenType2}.`);
      }
    }
  }
  function tokenize(expr) {
    const tokens = [];
    let isEscaped = false;
    let token = [];
    for (let i = 0; i < expr.length; i++) {
      const c = expr.charAt(i);
      if (isEscaped) {
        if (c === "(" || c === ")" || c === "\\" || /\s/.test(c)) {
          token.push(c);
          isEscaped = false;
        } else {
          throw new Error(`Tag expression "${expr}" could not be parsed because of syntax error: Illegal escape before "${c}".`);
        }
      } else if (c === "\\") {
        isEscaped = true;
      } else if (c === "(" || c === ")" || /\s/.test(c)) {
        if (token.length > 0) {
          tokens.push(token.join(""));
          token = [];
        }
        if (!/\s/.test(c)) {
          tokens.push(c);
        }
      } else {
        token.push(c);
      }
    }
    if (token.length > 0) {
      tokens.push(token.join(""));
    }
    return tokens;
  }
  function isUnary(token) {
    return "not" === token;
  }
  function isBinary(token) {
    return "or" === token || "and" === token;
  }
  function isOp(token) {
    return ASSOC[token] !== void 0;
  }
  function peek(stack) {
    return stack[stack.length - 1];
  }
  function pop(stack) {
    if (stack.length === 0) {
      throw new Error("empty stack");
    }
    return stack.pop();
  }
  function pushExpr(token, stack) {
    if (token === "and") {
      const rightAndExpr = pop(stack);
      stack.push(new And(pop(stack), rightAndExpr));
    } else if (token === "or") {
      const rightOrExpr = pop(stack);
      stack.push(new Or(pop(stack), rightOrExpr));
    } else if (token === "not") {
      stack.push(new Not(pop(stack)));
    } else {
      stack.push(new Literal(token));
    }
  }
  var Literal = class {
    constructor(value) {
      this.value = value;
    }
    evaluate(variables) {
      return variables.indexOf(this.value) !== -1;
    }
    toString() {
      return this.value.replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)").replace(/\s/g, "\\ ");
    }
  };
  var Or = class {
    constructor(leftExpr, rightExpr) {
      this.leftExpr = leftExpr;
      this.rightExpr = rightExpr;
    }
    evaluate(variables) {
      return this.leftExpr.evaluate(variables) || this.rightExpr.evaluate(variables);
    }
    toString() {
      return "( " + this.leftExpr.toString() + " or " + this.rightExpr.toString() + " )";
    }
  };
  var And = class {
    constructor(leftExpr, rightExpr) {
      this.leftExpr = leftExpr;
      this.rightExpr = rightExpr;
    }
    evaluate(variables) {
      return this.leftExpr.evaluate(variables) && this.rightExpr.evaluate(variables);
    }
    toString() {
      return "( " + this.leftExpr.toString() + " and " + this.rightExpr.toString() + " )";
    }
  };
  var Not = class {
    constructor(expr) {
      this.expr = expr;
    }
    evaluate(variables) {
      return !this.expr.evaluate(variables);
    }
    toString() {
      if (this.expr instanceof And || this.expr instanceof Or) {
        return "not " + this.expr.toString();
      }
      return "not ( " + this.expr.toString() + " )";
    }
  };
  var True = class {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    evaluate(variables) {
      return true;
    }
    toString() {
      return "true";
    }
  };

  // parser/core.js
  function plan(text, uri, definitions, tagExpression = "") {
    if (typeof text !== "string" || text.length > 131072) throw Error("Feature must be at most 128 KiB");
    const newId = IdGenerator_exports.incrementing();
    const document = new import_gherkin.Parser(new import_gherkin.AstBuilder(newId), new import_gherkin.GherkinClassicTokenMatcher()).parse(text);
    const locations = /* @__PURE__ */ new Map();
    function visit(node) {
      if (!node || typeof node !== "object") return;
      if (node.id && node.location) locations.set(node.id, node.location);
      Object.values(node).forEach((v) => Array.isArray(v) ? v.forEach(visit) : visit(v));
    }
    visit(document);
    const expressions = definitions.filter((d) => !d.hook).map((d) => ({
      ...d,
      expression: new CucumberExpression(d.pattern, new ParameterTypeRegistry())
    }));
    const filter = parse2(tagExpression);
    return (0, import_gherkin.compile)(document, uri, newId).filter((p) => filter.evaluate(p.tags.map((t) => t.name))).map((p) => ({
      id: `${uri}:${p.id}`,
      name: p.name,
      uri,
      tags: p.tags.map((t) => t.name),
      location: locations.get(p.astNodeIds[0]),
      steps: p.steps.map((s) => {
        const matches = expressions.map((d) => ({ d, args: d.expression.match(s.text) })).filter((m) => m.args !== null);
        const match = matches.length === 1 ? matches[0] : null;
        return {
          text: s.text,
          location: locations.get(s.astNodeIds[0]),
          definition: match == null ? void 0 : match.d.id,
          realm: match == null ? void 0 : match.d.realm,
          requires: (match == null ? void 0 : match.d.requires) || [],
          args: (match == null ? void 0 : match.args.map((a) => a.getValue(null))) || [],
          argument: s.argument,
          error: matches.length === 0 ? "Undefined step" : matches.length > 1 ? `Ambiguous step: ${matches.map((m) => m.d.id).join(", ")}` : void 0
        };
      })
    }));
  }
  function draft(events) {
    const lines = ["@kora @recorded @review", "Feature: Recorded gameplay", "  Scenario: Review this recording"];
    let target = false;
    for (const e of events) {
      const d = e.data || {};
      if (e.kind === "target.selected" && d.label === "Browse Vending Machine" && !target) {
        lines.push("    Given I am at the configured soda vending machine");
        lines.push('    And I have enough cash and inventory capacity for 1 "soda"');
        lines.push('    When I select "Browse Vending Machine" on the machine');
        target = true;
      } else if (e.kind === "purchase.confirmed" && d.shopId === "vendingmachine" && d.itemName === "soda" && target) {
        lines.push(`    And I buy ${d.count} "soda" through the inventory UI`);
        lines.push(`    Then my inventory should contain ${d.count} more "soda"`);
        lines.push(`    And my cash should have decreased by ${d.price}`);
      } else {
        lines.push(`    # Observed ${String(e.kind).replace(/[\r\n]/g, " ")}; review in timeline`);
      }
    }
    lines.push("    # Review assertions and fixture before replay. Retain the original timeline.");
    return lines.join("\n") + "\n";
  }

  // parser/runtime.js
  var register = globalThis.exports;
  register("parseFeature", (text, uri, definitions, tags) => {
    try {
      return JSON.stringify({ ok: true, scenarios: plan(text, uri, JSON.parse(definitions), tags || "") });
    } catch (e) {
      return JSON.stringify({ ok: false, error: String(e.message || e) });
    }
  });
  register("recordingDraft", (events) => draft(JSON.parse(events)));
})();
/*! Bundled license information:

reflect-metadata/Reflect.js:
  (*! *****************************************************************************
  Copyright (C) Microsoft. All rights reserved.
  Licensed under the Apache License, Version 2.0 (the "License"); you may not use
  this file except in compliance with the License. You may obtain a copy of the
  License at http://www.apache.org/licenses/LICENSE-2.0

  THIS CODE IS PROVIDED ON AN *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
  WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
  MERCHANTABLITY OR NON-INFRINGEMENT.

  See the Apache Version 2.0 License for specific language governing permissions
  and limitations under the License.
  ***************************************************************************** *)

regexp-match-indices/config.js:
regexp-match-indices/native.js:
regexp-match-indices/implementation.js:
regexp-match-indices/polyfill.js:
regexp-match-indices/shim.js:
regexp-match-indices/index.js:
  (*!
  Copyright 2019 Ron Buckton

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  *)
*/
