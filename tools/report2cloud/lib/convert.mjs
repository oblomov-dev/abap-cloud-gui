// report2cloud - a classic ABAP report as an abap-cloud-gui report class.
//
//   import { convert } from "./lib/convert.mjs";
//   const result = convert(source, { file: "zflights.prog.abap", textpool });
//
// The report is parsed with @abaplint/core, the parser of the ecosystem, and
// rewritten statement by statement: PARAMETERS and SELECT-OPTIONS become
// PUBLIC attributes and the chain of selection_screen( ), the event blocks
// become the methods of z2ui5_cl_cgui_report with the same names, WRITE /
// ULINE / SKIP / FORMAT the calls of the list, CL_SALV_TABLE and
// REUSE_ALV_GRID_DISPLAY one alv( ) chain, MESSAGE message( ), FORMs private
// methods and PERFORM their calls. Everything else - the logic of the report
// - is copied as it is written.
//
// DETERMINISTIC, AND IT REFUSES RATHER THAN GUESSES
//
// The same report gives the same class, byte for byte - no time stamps, no
// heuristics that depend on anything but the source and its text pool. What
// has no counterpart in a browser app (CALL SCREEN, dynpro modules, batch
// input, SUBMIT, native SQL, ...) is refused with the file, the row and the
// column and the reason, the way cap2UI5's abap2js refuses: a conversion
// that comes out is meant to behave as the report did, and one that cannot
// says so instead of producing something that merely compiles. Every
// refusal is collected - the migration report lists all of them at once.
//
// What converts but needs a person or the AI step afterwards - a table that
// is not released on ABAP Cloud, a selection text the source does not carry,
// a formatting option of WRITE the list does not know - is a TODO of the
// migration report, with its position in the generated class.
import { createRequire } from "node:module";
import {
  abaplint, after, child, children, findAll, hasSeq, isToken, key, kind, lc, literal, nodeText,
  partTokens, renderTokens, stmtTokens, uc, unquote, words,
} from "./abap.mjs";
import { classXml, longLines, normalizeAbap } from "./abapgit.mjs";

const require = createRequire(import.meta.url);
const { Indent } = require("@abaplint/core/build/src/pretty_printer/indent");

// the event blocks of a report
const EVENTS = new Set(["Initialization", "LoadOfProgram", "AtSelectionScreen", "StartOfSelection",
  "EndOfSelection", "AtLineSelection", "AtUserCommand", "TopOfPage", "EndOfPage", "AtPF", "Get"]);

// declarations that are global in a report wherever they stand
const DECL = new Set(["Data", "DataBegin", "DataEnd", "Type", "TypeBegin", "TypeEnd", "IncludeType",
  "Constant", "ConstantBegin", "ConstantEnd", "Tables", "Parameter", "SelectOption", "SelectionScreen",
  "Ranges", "FieldSymbol", "TypePools", "TypePool", "Nodes", "Controls", "StaticBegin", "StaticEnd", "Static",
  "TypeEnum", "TypeEnumBegin", "TypeEnumEnd"]);

// statements with no counterpart - refused wherever they stand
const REFUSED = {
  CallScreen: "CALL SCREEN - a dynpro has no counterpart in a browser app; build the screen as an abap2UI5 view or a popup",
  SetScreen: "SET SCREEN - dynpro flow logic has no counterpart",
  CallSelectionScreen: "CALL SELECTION-SCREEN - a second selection screen is not supported (abap-cloud-gui roadmap)",
  CallDialog: "CALL DIALOG - dialog modules have no counterpart",
  CallTransaction: "CALL TRANSACTION - no SAP GUI transaction can be started from a browser app (batch input with USING is no API on ABAP Cloud either); call the released API of the application instead",
  Submit: "SUBMIT - another report cannot be started from here; convert it as well and navigate to its class with client->nav_app_call( )",
  ExecSQL: "EXEC SQL - native SQL is not available on ABAP Cloud; use ABAP SQL on a released CDS view",
  Module: "MODULE - dynpro modules have no counterpart",
  Include: "INCLUDE - the include is not part of the input; inline its source into the report and convert again",
  Define: "DEFINE - macros are not converted; expand them in the source first",
  Nodes: "NODES - logical databases have no counterpart; read the data with ABAP SQL",
  Get: "GET - logical database events have no counterpart; read the data with ABAP SQL",
  Reject: "REJECT - logical database statement",
  Controls: "CONTROLS - table controls and tabstrips belong to dynpros",
  EndOfPage: "END-OF-PAGE - the list has no page footer",
  AtPF: "AT PFnn - the list has no function keys",
  GetCursor: "GET CURSOR - the list has no cursor; a hotspot with HIDE gives the clicked line",
  ReadLine: "READ LINE - the list cannot be read back; keep the data in an internal table",
  ModifyLine: "MODIFY LINE - the list cannot be changed after it is written",
  Window: "WINDOW - list windows have no counterpart",
  SetUserCommand: "SET USER-COMMAND - triggers no event here",
  PrintControl: "PRINT-CONTROL - printing is not supported",
  CallSubscreen: "CALL SUBSCREEN - dynpro statement",
  SetCursor: "SET CURSOR - dynpro statement",
  Local: "LOCAL - not available in methods",
  ScrollList: "SCROLL LIST - the list has no scroll position",
  Communication: "COMMUNICATION - CPI-C is obsolete",
  CallKernel: "CALL - system functions are not available",
  SystemCall: "SYSTEM-CALL - not available",
  EditorCall: "EDITOR-CALL - SAP GUI editor",
  GenerateReport: "GENERATE REPORT - dynamic programs are not available on ABAP Cloud",
  GenerateSubroutine: "GENERATE SUBROUTINE POOL - dynamic programs are not available on ABAP Cloud",
  InsertReport: "INSERT REPORT - dynamic programs are not available on ABAP Cloud",
  Supply: "SUPPLY - contexts are obsolete",
  Demand: "DEMAND - contexts are obsolete",
  Contexts: "CONTEXTS - contexts are obsolete",
  CreateOLE: "CREATE OBJECT ... OLE - SAP GUI desktop integration",
  CallOLE: "CALL METHOD OF - SAP GUI desktop integration",
  SetProperty: "SET PROPERTY OF - SAP GUI desktop integration",
  GetProperty: "GET PROPERTY OF - SAP GUI desktop integration",
};

// function modules with no counterpart on a browser app - refused
const REFUSED_FUNCTIONS = {
  POPUP_TO_CONFIRM: "POPUP_TO_CONFIRM waits for the answer; in abap2UI5 the popup is asynchronous - call popup_to_confirm( question = ... ucomm = ... ) and continue in at_user_command( ) with that ucomm",
  POPUP_TO_CONFIRM_STEP: "POPUP_TO_CONFIRM_STEP waits for the answer; use popup_to_confirm( ) and at_user_command( )",
  POPUP_TO_DECIDE: "POPUP_TO_DECIDE waits for the answer; use popup_to_confirm( ) and at_user_command( )",
  POPUP_GET_VALUES: "POPUP_GET_VALUES waits for the input; use a popup of abap2UI5-addons/popups",
  GUI_DOWNLOAD: "GUI_DOWNLOAD writes to the SAP GUI frontend; offer the file with an abap2UI5 download instead",
  GUI_UPLOAD: "GUI_UPLOAD reads from the SAP GUI frontend; use an abap2UI5 file uploader instead",
  WS_DOWNLOAD: "WS_DOWNLOAD writes to the SAP GUI frontend",
  WS_UPLOAD: "WS_UPLOAD reads from the SAP GUI frontend",
  F4IF_FIELD_VALUE_REQUEST: "F4IF_FIELD_VALUE_REQUEST calls a search help; answer F4 with value_help_popup( ) on a table",
  RS_REFRESH_FROM_SELECTOPTIONS: "RS_REFRESH_FROM_SELECTOPTIONS reads dynpro fields; the attributes hold the values",
  DYNP_VALUES_READ: "DYNP_VALUES_READ reads dynpro fields; the attributes hold the values",
  DYNP_VALUES_UPDATE: "DYNP_VALUES_UPDATE writes dynpro fields; set the attributes instead",
  BDC_OPEN_GROUP: "batch input sessions have no counterpart on ABAP Cloud",
  BDC_INSERT: "batch input sessions have no counterpart on ABAP Cloud",
  BDC_CLOSE_GROUP: "batch input sessions have no counterpart on ABAP Cloud",
  REUSE_ALV_HIERSEQ_LIST_DISPLAY: "a hierarchical sequential list is not supported by the ALV of abap-cloud-gui",
  REUSE_ALV_POPUP_TO_SELECT: "the ALV popup waits for the selection; use value_help_popup( ) or z2ui5_cl_popup_to_select",
  SAPGUI_PROGRESS_INDICATOR: "SAPGUI_PROGRESS_INDICATOR shows progress in SAP GUI - drop it",
};

// statements that only lay out or decorate a list or screen - dropped, noted
const LAYOUT_ONLY = {
  Position: "POSITION - the list has no columns",
  Back: "BACK - the list has no columns",
  Reserve: "RESERVE - the list has no pages to reserve lines on",
  Summary: "SUMMARY - the list knows no intensified output",
  Detail: "DETAIL - the list knows no intensified output",
  SetLeft: "SET LEFT SCROLL-BOUNDARY - the list does not scroll horizontally",
  SetMargin: "SET MARGIN - printing is not supported",
  SetBlank: "SET BLANK LINES - the list writes no blank lines",
};

// FORMAT COLOR / WRITE COLOR - the colors of the list are UI5 value states
const COLORS = {
  COL_BACKGROUND: "none", 0: "none", OFF: "none",
  COL_HEADING: "key", 1: "key",
  COL_NORMAL: "none", 2: "none",
  COL_TOTAL: "total", 3: "total",
  COL_KEY: "key", 4: "key",
  COL_POSITIVE: "positive", 5: "positive",
  COL_NEGATIVE: "negative", 6: "negative",
  COL_GROUP: "total", 7: "total",
};
const colorConst = (c) => `z2ui5_cl_cgui_list=>cs_color-${c}`;

// WRITE ... AS ICON with an icon of type pool ICON - the UI5 icon that shows
// the same, from the icons that exist in UI5 1.71
const ICONS = {
  icon_okay: "sap-icon://accept", icon_checked: "sap-icon://accept", icon_cancel: "sap-icon://decline",
  icon_incomplete: "sap-icon://decline", icon_green_light: "sap-icon://status-positive",
  icon_yellow_light: "sap-icon://status-critical", icon_red_light: "sap-icon://status-negative",
  icon_led_green: "sap-icon://status-positive", icon_led_yellow: "sap-icon://status-critical",
  icon_led_red: "sap-icon://status-negative", icon_led_inactive: "sap-icon://status-inactive",
  icon_light_out: "sap-icon://status-inactive", icon_delete: "sap-icon://delete",
  icon_create: "sap-icon://create", icon_change: "sap-icon://edit", icon_display: "sap-icon://display",
  icon_warning: "sap-icon://warning", icon_message_warning: "sap-icon://warning",
  icon_error: "sap-icon://error", icon_message_error: "sap-icon://error",
  icon_information: "sap-icon://message-information", icon_message_information: "sap-icon://message-information",
  icon_failure: "sap-icon://error", icon_locked: "sap-icon://locked", icon_unlocked: "sap-icon://unlocked",
  icon_mail: "sap-icon://email", icon_print: "sap-icon://print", icon_refresh: "sap-icon://refresh",
  icon_search: "sap-icon://search", icon_settings: "sap-icon://action-settings",
};

// the statements that open and close a block
const OPENERS = new Set(["If", "Case", "Loop", "Do", "While", "SelectLoop", "Try", "At", "AtFirst", "AtLast", "OnChange", "Provide", "LoopAtScreen"]);
const CLOSERS = new Set(["EndIf", "EndCase", "EndLoop", "EndDo", "EndWhile", "EndSelect", "EndTry", "EndAt", "EndOn", "EndProvide"]);

// SAP GUI controls - they need a dynpro container
const GUI_CONTROL = /\bcl_gui_(alv_grid|custom_container|docking_container|splitter_container|dialogbox_container|container|html_viewer|textedit|picture|toolbar|simple_tree|column_tree|list_tree|gos_container|easy_splitter_container)\b/;

// statements a body keeps chained when the report chains them
const CHAINABLE = new Set(["Clear", "Free", "Data", "DataBegin", "DataEnd", "Constant", "Type", "TypeBegin", "TypeEnd", "Static", "FieldSymbol", "Refresh"]);

// the screen fields LOOP AT SCREEN / MODIFY SCREEN can change here, and how
const SCREEN_FLAGS = new Set(["active", "input", "required", "invisible"]);
const SCREEN_FIELDS = new Set(["name", "group1", ...SCREEN_FLAGS]);

// names of z2ui5_cl_cgui_report a FORM must not take as method name
const RESERVED_METHODS = new Set(["initialization", "selection_screen", "at_selection_screen_output",
  "at_selection_screen_on", "at_selection_screen", "start_of_selection", "at_line_selection",
  "at_user_command", "at_value_request", "write", "list", "alv", "message", "popup_to_confirm",
  "value_help_popup", "leave_to_selection_screen", "set_title", "set_variant", "client",
  "z2ui5_if_app~main", "main", "top_of_page", "at_selection_screen_ucomm", "constructor"]);

const BUILTIN_TYPES = new Set(["string", "xstring", "i", "int1", "int2", "int4", "int8", "d", "t", "f", "c", "n",
  "x", "p", "decfloat16", "decfloat34", "utclong", "abap_bool", "any", "data", "simple", "clike", "csequence",
  "xsequence", "numeric", "decfloat", "object", "table", "index", "standard", "sorted", "hashed", "line", "ref",
  "abap_true", "abap_false", "string_table", "sy", "syst", "char1", "boolean", "abap_boolean", "timestamp",
  "timestampl", "sydatum", "syuzeit", "syuname", "symsgid", "symsgty", "symsgno", "symsgv", "sytabix",
  "xsdboolean", "abap_char1", "abap_typekind", "ty_t_cgui_value", "ty_s_cgui_value"]);

// well-known on-premise tables and their released successors on ABAP Cloud
// (a hint for the person or the AI step - verify before using it)
const SUCCESSORS = {
  sflight: "/DMO/FLIGHT (ABAP Flight Reference Scenario) or a released CDS view of your own",
  scarr: "/DMO/CARRIER (ABAP Flight Reference Scenario)",
  spfli: "/DMO/CONNECTION (ABAP Flight Reference Scenario)",
  sbook: "/DMO/BOOKING (ABAP Flight Reference Scenario)",
  scustom: "/DMO/CUSTOMER (ABAP Flight Reference Scenario)",
  mara: "I_Product", makt: "I_ProductDescription", marc: "I_ProductPlant", mard: "I_ProductStorageLocation",
  t001: "I_CompanyCode", t001w: "I_Plant", kna1: "I_Customer", lfa1: "I_Supplier",
  bkpf: "I_JournalEntry", bseg: "I_JournalEntryItem", acdoca: "I_JournalEntryItem",
  vbak: "I_SalesOrder", vbap: "I_SalesOrderItem", likp: "I_OutboundDelivery", lips: "I_OutboundDeliveryItem",
  vbrk: "I_BillingDocument", vbrp: "I_BillingDocumentItem", ekko: "I_PurchaseOrderAPI01",
  ekpo: "I_PurchaseOrderItemAPI01", eban: "I_PurchaseRequisitionItemAPI01", t005: "I_Country",
  t005t: "I_CountryText", tcurc: "I_Currency", t006: "I_UnitOfMeasure", usr02: "I_User (no direct successor)",
  cl_salv_table: "abap-cloud-gui alv( )", cl_gui_frontend_services: "no successor - no SAP GUI frontend",
};

class Converter {
  constructor(source, opts) {
    this.source = source.replace(/\r\n?/g, "\n");
    this.lines = this.source.split("\n");
    this.file = opts.file ?? "zreport.prog.abap";
    this.pool = opts.textpool ?? { title: "", symbols: new Map(), selection: new Map() };
    this.programName = opts.programName;
    this.className = opts.className;
    this.refusals = [];
    this.mapped = [];
    this.todos = [];
    this.notes = new Map();
  }

  // ---------------------------------------------------------------- report

  refuse(at, message) {
    const tok = at && (at.getFirstToken ? at.getFirstToken() : at);
    this.refusals.push({ row: tok ? tok.getRow() : 0, col: tok ? tok.getCol() : 0, message });
  }

  map(s, target) {
    const first = s.getFirstToken();
    let text = renderTokens(stmtTokens(s), new Map(), s.getColon()).replace(/\s+/g, " ");
    if (text.length > 70) text = text.slice(0, 67) + "...";
    const pos = s.getColon() ? partTokens(s)[0] ?? first : first;
    this.mapped.push({ row: pos.getRow(), col: pos.getCol(), classic: text, target });
  }

  todo(s, message) {
    const first = s && s.getFirstToken();
    this.todos.push({ row: first ? first.getRow() : 0, col: first ? first.getCol() : 0, message });
  }

  note(text) {
    this.notes.set(text, (this.notes.get(text) ?? 0) + 1);
  }

  // ----------------------------------------------------------------- parse

  parse() {
    const name = this.programName ?? "zreport";
    const config = abaplint.Config.getDefault().get();
    config.syntax = { version: abaplint.Version.v758, errorNamespace: "." };
    const reg = new abaplint.Registry(new abaplint.Config(JSON.stringify(config)));
    reg.addFile(new abaplint.MemoryFile(`${lc(name).replace(/\//g, "#")}.prog.abap`, this.source));
    reg.parse();
    const file = reg.getFirstObject().getABAPFiles()[0];
    this.stmts = file.getStatements().filter((s) => kind(s) !== "Empty");
  }

  run() {
    this.parse();
    this.segment();
    if (!this.programName && this.header) this.programName = lc(this.header.name);
    this.programName = this.programName ?? "zreport";
    this.className = lc(this.className ?? defaultClassName(this.programName));
    this.analyze();
    const out = this.generate();
    return out;
  }

  // ---------------------------------------------------------------- segment

  /** the report as units: the global declarations, the event blocks, the
   *  FORMs and the local classes, each with its statements */
  segment() {
    this.decls = [];
    this.events = [];
    this.forms = [];
    this.locals = [];
    this.header = undefined;
    let current;           // the unit statements go to
    let implicit;          // statements before the first event: START-OF-SELECTION
    let pendingComments = [];

    for (let i = 0; i < this.stmts.length; i++) {
      const s = this.stmts[i];
      const k = kind(s);

      if (k === "Unknown") {
        this.refuse(s, `the parser does not understand this statement - a syntax error, or a statement of a newer release: ${shortText(s)}`);
        continue;
      }
      if (k === "MacroCall" || k === "MacroContent") {
        this.refuse(s, "a macro call - macros are not converted; expand them in the source first");
        continue;
      }
      if (k === "Comment") {
        // a comment belongs to the statement after it - trailing comments
        // of a block (the banner of the next FORM) are dropped
        pendingComments.push(s);
        continue;
      }
      if (k === "Report" || k === "Program") {
        const name = child(s, "ReportName");
        const msg = child(s, "MessageClass");
        this.header = { name: name ? nodeText(name) : "zreport", messageClass: msg ? uc(nodeText(msg)) : "" };
        this.map(s, "the class, `INHERITING FROM z2ui5_cl_cgui_report`");
        pendingComments = [];
        continue;
      }
      if (k === "Module") {
        this.refuse(s, REFUSED.Module);
        const end = this.findEnd(i, "EndModule");
        i = end;
        current = undefined;
        continue;
      }
      if (k === "Define") {
        this.refuse(s, REFUSED.Define);
        i = this.findEnd(i, "EndOfDefinition");
        continue;
      }
      if (k === "Form") {
        const end = this.findEnd(i, "EndForm");
        this.forms.push({ stmt: s, body: this.stmts.slice(i + 1, end).filter((x) => kind(x) !== "Empty"), end: this.stmts[end] });
        i = end;
        current = undefined;
        pendingComments = [];
        continue;
      }
      if (["ClassDefinition", "ClassImplementation", "Interface", "ClassDeferred", "InterfaceDeferred",
        "ClassDefinitionLoad", "InterfaceLoad"].includes(k)) {
        let end = i;
        if (k === "ClassDefinition" || k === "ClassImplementation") end = this.findEnd(i, "EndClass");
        if (k === "Interface") end = this.findEnd(i, "EndInterface");
        this.locals.push({ kind: k, stmts: this.stmts.slice(i, end + 1), comments: pendingComments });
        pendingComments = [];
        i = end;
        current = undefined;
        continue;
      }
      if (EVENTS.has(k)) {
        current = { stmt: s, kind: k, stmts: [] };
        this.events.push(current);
        pendingComments = [];
        continue;
      }
      if (DECL.has(k)) {
        // global in a report, wherever it stands - a run of BEGIN OF ... END
        // OF is taken as a whole
        const end = this.declEnd(i);
        for (let j = i; j <= end; j++) this.decls.push(this.stmts[j]);
        i = end;
        pendingComments = [];
        continue;
      }
      if (!current) {
        // executable statements before the first event belong to
        // START-OF-SELECTION
        if (!implicit) {
          implicit = { stmt: s, kind: "StartOfSelection", implicit: true, stmts: [] };
          this.events.push(implicit);
        }
        current = implicit;
      }
      current.stmts.push(...pendingComments, s);
      pendingComments = [];
    }
  }

  findEnd(i, endKind) {
    for (let j = i + 1; j < this.stmts.length; j++) {
      if (kind(this.stmts[j]) === endKind) return j;
    }
    this.refuse(this.stmts[i], `no ${endKind.replace(/([a-z])([A-Z])/g, "$1 $2").toUpperCase()} for this statement`);
    return this.stmts.length - 1;
  }

  declEnd(i) {
    const begins = { DataBegin: "DataEnd", TypeBegin: "TypeEnd", ConstantBegin: "ConstantEnd", StaticBegin: "StaticEnd", TypeEnumBegin: "TypeEnumEnd" };
    const k = kind(this.stmts[i]);
    if (!begins[k]) return i;
    let depth = 0;
    for (let j = i; j < this.stmts.length; j++) {
      const kj = kind(this.stmts[j]);
      if (kj === k) depth++;
      if (kj === begins[k]) depth--;
      if (depth === 0) return j;
    }
    return i;
  }

  // ---------------------------------------------------------------- analyze

  analyze() {
    // the names of the report's global data objects and types
    this.globalData = new Set();
    this.globalTypes = new Set();
    for (const s of this.decls) {
      const k = kind(s);
      const name = declName(s);
      if (!name) continue;
      if (["Data", "DataBegin", "Constant", "ConstantBegin", "Parameter", "SelectOption", "Ranges", "Tables"].includes(k)) {
        if (k === "Data" && this.insideBegin(s)) continue;
        this.globalData.add(lc(name));
      }
      if (["Type", "TypeBegin"].includes(k) && !this.insideBegin(s)) this.globalTypes.add(lc(name));
    }
    this.localNames = new Set(this.locals.flatMap((u) => u.stmts)
      .filter((s) => ["ClassDefinition", "Interface", "ClassDeferred", "InterfaceDeferred"].includes(kind(s)))
      .map((s) => lc(nodeText(child(s, "ClassName") ?? child(s, "InterfaceName") ?? s.getChildren()[1]))));

    // every identifier of the report - generated names must not collide
    this.identifiers = new Set(this.stmts.flatMap((s) => s.getTokens().map((t) => lc(t.getStr()))));
    this.msgVar = this.identifiers.has("lv_message") ? "lv_r2c_message" : "lv_message";

    // select-options and RANGES have a header line in a report - a method
    // reads and writes it through a work area of its own (ls_<name>)
    this.headerTables = new Set(this.decls.filter((s) => ["SelectOption", "Ranges"].includes(kind(s))).map((s) => lc(declName(s))));
    this.methodWa = new Map();
    this.prelude = new Map();
    this.msgDeclared = new Set();

    this.analyzeForms();
    this.analyzeTables();
    this.analyzeAlv();
    this.analyzeScreen();
  }

  insideBegin(s) {
    // a DATA inside DATA BEGIN OF ... END OF is a component, not a variable
    const idx = this.decls.indexOf(s);
    let depth = 0;
    for (let j = 0; j < idx; j++) {
      const k = kind(this.decls[j]);
      if (k === "DataBegin" || k === "TypeBegin" || k === "ConstantBegin") depth++;
      if (k === "DataEnd" || k === "TypeEnd" || k === "ConstantEnd") depth--;
    }
    return depth > 0;
  }

  analyzeForms() {
    this.formByName = new Map();
    const used = new Set(this.forms.map((f) => lc(nodeText(child(f.stmt, "FormName")))));
    for (const f of this.forms) {
      const name = lc(nodeText(child(f.stmt, "FormName")));
      let method = name.replace(/[^a-z0-9_]/g, "_");
      if (RESERVED_METHODS.has(method) || this.globalData.has(method)) method = `form_${method}`.slice(0, 30);
      while (used.has(method) && method !== name) method = `${method.slice(0, 28)}_f`;
      f.name = name;
      f.method = method;
      f.params = [];
      const written = new Set(f.body.flatMap((s) => findAll(s, "Target").map((t) => lc(t.getFirstToken().getStr()))));
      for (const [section, k] of [["FormTables", "tables"], ["FormUsing", "using"], ["FormChanging", "changing"]]) {
        const sec = child(f.stmt, section);
        if (!sec) continue;
        for (const p of children(sec, "FormParam")) {
          const byValue = child(p, "PassByValue");
          const nameNode = byValue ? child(byValue, "FormParamName") : child(p, "FormParamName");
          const pname = lc(nodeText(nameNode));
          f.params.push({ name: pname, kind: k, byValue: !!byValue, node: p, written: written.has(pname) });
        }
      }
      const raising = child(f.stmt, "FormRaising");
      f.raising = raising ? children(raising, "ClassName").map((c) => lc(nodeText(c))) : [];
      this.formByName.set(name, f);
    }
  }

  /** TABLES dbtab: kept as a typed work area where the code uses it, dropped
   *  where it only types select-options and parameters */
  analyzeTables() {
    this.tablesKept = new Set();
    const tables = this.decls.filter((s) => kind(s) === "Tables").map((s) => lc(declName(s)));
    if (!tables.length) return;
    const body = [...this.events.flatMap((e) => e.stmts), ...this.forms.flatMap((f) => f.body)];
    for (const s of body) {
      if (kind(s) === "Comment") continue;
      const dbTokens = new Set(findAll(s, "DatabaseTable").flatMap((n) => n.getTokens().map(key)));
      for (const t of s.getTokens()) {
        if (dbTokens.has(key(t))) continue;
        const name = lc(t.getStr());
        if (tables.includes(name)) this.tablesKept.add(name);
      }
    }
  }

  /** CL_SALV_TABLE and REUSE_ALV_*: what each statement becomes - looked at
   *  over the whole report first, because the settings of a grid are often
   *  made in another FORM than the one that displays it */
  analyzeAlv() {
    this.alvPlan = new Map();     // statement -> { action: "drop" | "alv" | "skip", ... }
    this.salv = new Map();        // salv variable -> { table, settings, lineSelection }
    const cols = new Map();       // columns variable -> salv variable
    const col = new Map();        // column variable -> { salv, name }
    this.salvVars = new Set();
    const fcat = new Map();       // field catalog table -> [{ name, text, hidden }]
    const fcatWa = new Map();     // field catalog work area -> current column
    this.fcatVars = new Set();
    this.layoutVars = new Set();
    this.alvCallbacks = new Map(); // FORM name -> callback kind
    this.fcat = fcat;

    // the variables: REF TO cl_salv_*, the field catalog and layout types
    const allStmts = [...this.decls, ...this.events.flatMap((e) => e.stmts), ...this.forms.flatMap((f) => f.body)];
    for (const s of allStmts) {
      if (!["Data", "Static"].includes(kind(s))) continue;
      const text = lc(renderTokens(stmtTokens(s)));
      const name = lc(declName(s) ?? "");
      if (/type\s+ref\s+to\s+c[lx]_salv_/.test(text)) this.salvVars.add(name);
      if (/type\s+(standard\s+table\s+of\s+|table\s+of\s+|line\s+of\s+)?(slis_t_fieldcat_alv|slis_fieldcat_alv|lvc_t_fcat|lvc_s_fcat)\b/.test(text)) this.fcatVars.add(name);
      if (/type\s+(slis_layout_alv|lvc_s_layo|slis_print_alv|disvariant|slis_t_sortinfo_alv|slis_t_event|slis_t_listheader|lvc_t_sort)\b/.test(text)) this.layoutVars.add(name);
    }

    const tryStack = [];
    const seq = [...this.events.flatMap((e) => e.stmts), ...this.forms.flatMap((f) => f.body)];
    for (let si = 0; si < seq.length; si++) {
      const s = seq[si];
      const k = kind(s);
      const toks = stmtTokens(s).map((t) => t.getStr());
      const flat = lc(toks.join(" "));

      if (k === "Try") { tryStack.push({ stmt: s, clauses: [], cleanup: false }); continue; }
      if (k === "Catch" && tryStack.length) {
        const names = children(s, "ClassName").map((c) => lc(nodeText(c)));
        tryStack[tryStack.length - 1].clauses.push({ stmt: s, names, body: [] });
        continue;
      }
      if (k === "Cleanup" && tryStack.length) { tryStack[tryStack.length - 1].cleanup = true; continue; }
      if (k === "EndTry" && tryStack.length) {
        const t = tryStack.pop();
        let kept = 0;
        for (const c of t.clauses) {
          if (c.names.every((n) => /^cx_salv_/.test(n))) {
            this.alvPlan.set(c.stmt, { action: "skip", reason: "CATCH of a CL_SALV_TABLE exception - alv( ) raises none" });
            for (const b of c.body) this.alvPlan.set(b, { action: "skip" });
          } else {
            kept++;
            if (c.names.some((n) => /^cx_salv_/.test(n))) this.alvPlan.set(c.stmt, { action: "catch", names: c.names.filter((n) => !/^cx_salv_/.test(n)) });
          }
        }
        if (kept === 0 && !t.cleanup && t.clauses.length) {
          this.alvPlan.set(t.stmt, { action: "skip" });
          this.alvPlan.set(s, { action: "skip" });
        }
        continue;
      }
      if (tryStack.length) {
        const t = tryStack[tryStack.length - 1];
        if (t.clauses.length) t.clauses[t.clauses.length - 1].body.push(s);
      }

      // cl_salv_table=>factory( IMPORTING r_salv_table = x CHANGING t_table = itab )
      if (/cl_salv_table\s*=>\s*factory/.test(flat)) {
        const m = /r_salv_table\s*=\s*(?:data\s*\(\s*)?([\w/]+)/.exec(flat);
        const tab = /t_table\s*=\s*([\w/-]+)/.exec(flat);
        if (!m || !tab) {
          this.refuse(s, "cl_salv_table=>factory( ) without r_salv_table and t_table - not understood");
          continue;
        }
        this.salvVars.add(m[1]);
        const tableTok = stmtTokens(s).find((t) => lc(t.getStr()) === tab[1].split("-")[0]);
        this.salv.set(m[1], { table: tab[1], tableTok, settings: [], lineSelection: false, displayed: false, stmt: s });
        this.alvPlan.set(s, { action: "drop", reason: "cl_salv_table=>factory( ) - alv( ) at display( )" });
        continue;
      }

      // a call chain over a SALV object: x->get_columns( )->get_column( 'A' )->set_long_text( ... )
      const chain = salvChain(s);
      if (chain) {
        let ctx;
        let target = chain.target;
        if (this.salv.has(chain.root)) ctx = { level: "salv", salv: chain.root };
        else if (cols.has(chain.root)) ctx = { level: "columns", salv: cols.get(chain.root) };
        else if (col.has(chain.root)) ctx = { level: "column", ...col.get(chain.root) };
        if (ctx) {
          let ok = true;
          for (const c of chain.calls) {
            const salv = this.salv.get(ctx.salv);
            const arg = c.arg;
            switch (`${ctx.level}.${c.name}`) {
              case "salv.get_columns": ctx = { ...ctx, level: "columns" }; break;
              case "columns.get_column":
                ctx = { ...ctx, level: "column", name: arg && /^['`]/.test(arg) ? uc(unquote(arg)) : undefined };
                break;
              case "salv.get_display_settings": ctx = { ...ctx, level: "display" }; break;
              case "salv.get_functions": ctx = { ...ctx, level: "functions" }; break;
              case "salv.get_event": ctx = { ...ctx, level: "event" }; break;
              case "salv.get_sorts": case "salv.get_aggregations": case "salv.get_layout": case "salv.get_selections":
              case "salv.get_filters":
                ctx = { ...ctx, level: "other" }; break;
              case "salv.display":
                salv.displayed = true;
                this.alvPlan.set(s, { action: "alv", salv: ctx.salv });
                break;
              case "display.set_list_header": salv.settings.push({ m: "set_title", arg }); break;
              case "column.set_long_text": case "column.set_medium_text": case "column.set_short_text":
                if (ctx.name) salv.settings.push({ m: "set_column_text", name: ctx.name, arg, rank: c.name });
                else ok = false;
                break;
              case "column.set_visible":
                if (ctx.name && /abap_false|' '|space/.test(lc(arg ?? ""))) salv.settings.push({ m: "set_column_hidden", name: ctx.name });
                else if (!ctx.name) ok = false;
                break;
              case "column.set_technical":
                if (ctx.name && !/abap_false|' '|space/.test(lc(arg ?? ""))) salv.settings.push({ m: "set_column_hidden", name: ctx.name });
                break;
              case "columns.set_optimize": case "functions.set_all": case "functions.set_default": case "display.set_striped_pattern":
              case "column.set_optimized": case "column.set_output_length":
                this.note("CL_SALV_TABLE settings without a counterpart (optimized widths, toolbar functions, striped rows) - the grid sorts and filters by itself");
                break;
              default:
                ok = false;
            }
          }
          if (chain.target) {
            if (ctx.level === "columns") cols.set(target, ctx.salv);
            else if (ctx.level === "column") col.set(target, { salv: ctx.salv, name: ctx.name });
            else if (ctx.level !== "salv") ok = ok && ["display", "functions", "event", "other"].includes(ctx.level);
            this.salvVars.add(target);
          }
          if (!this.alvPlan.has(s)) {
            this.alvPlan.set(s, ok
              ? { action: "drop", reason: "CL_SALV_TABLE setting - in the alv( ) chain" }
              : { action: "drop", reason: "CL_SALV_TABLE call", todo: `CL_SALV_TABLE call without a counterpart in the alv( ) chain, dropped: ${shortText(s)}` });
          }
          continue;
        }
      }

      // SET HANDLER ... FOR salv->get_event( ) - the double click
      if (k === "SetHandler") {
        const m = /for\s+([\w/]+)\s*->\s*get_event/.exec(flat) ?? /for\s+([\w/]+)\s*\./.exec(flat + ".");
        const v = m && (this.salv.has(m[1]) ? m[1] : undefined);
        if (v) {
          this.salv.get(v).lineSelection = true;
          this.alvPlan.set(s, { action: "drop", reason: "SET HANDLER of the SALV events - set_line_selection( )",
            todo: "the ALV event handler is dropped: move the code of its double click handler into at_line_selection( ) - row is the index of the clicked row" });
          continue;
        }
      }

      if (k === "CallFunction") {
        const fm = uc(unquote(nodeText(child(s, "FunctionName")).trim()));
        if (fm === "REUSE_ALV_FIELDCATALOG_MERGE" || fm === "LVC_FIELDCATALOG_MERGE") {
          this.alvPlan.set(s, { action: "drop", reason: `${fm} - the columns come from the table (RTTI)` });
          continue;
        }
        if (/^REUSE_ALV_(GRID|LIST)_DISPLAY(_LVC)?$/.test(fm)) {
          const p = functionParams(s);
          const table = p.get("t_outtab");
          if (!table) {
            this.refuse(s, `${fm} without TABLES t_outtab - not understood`);
            continue;
          }
          const plan = { action: "reuse", fm, table: nodeText(table.node), tableNode: table.node, settings: [], lineSelection: false };
          const title = p.get("i_grid_title") ?? p.get("i_title");
          if (title) plan.settings.push({ m: "set_title", arg: nodeText(title.node) });
          // the field catalog is read when the call is written - it is often
          // built in a FORM further down
          const fc = p.get("it_fieldcat") ?? p.get("it_fieldcat_lvc");
          plan.fieldcatVar = fc ? lc(nodeText(fc.node)) : undefined;
          const ucomm = p.get("i_callback_user_command");
          if (ucomm) {
            plan.lineSelection = true;
            const formName = lc(unquote(nodeText(ucomm.node).trim()));
            this.alvCallbacks.set(formName, { kind: "user_command", stmt: s });
          }
          for (const cb of ["i_callback_pf_status_set", "i_callback_top_of_page", "i_callback_html_top_of_page", "i_callback_html_end_of_list"]) {
            const v = p.get(cb);
            if (!v) continue;
            const formName = lc(unquote(nodeText(v.node).trim()));
            this.alvCallbacks.set(formName, { kind: cb, stmt: s });
          }
          for (const ignored of ["is_layout", "is_layout_lvc", "it_sort", "it_sort_lvc", "it_events", "is_variant", "i_save", "it_filter", "is_print", "it_excluding"]) {
            if (p.has(ignored)) plan.todos = [...(plan.todos ?? []), `${fm}: ${uc(ignored)} has no counterpart in the alv( ) chain and is dropped`];
          }
          this.alvPlan.set(s, plan);
          // IF sy-subrc <> 0 right after it checked the EXCEPTIONS of the
          // function - alv( ) raises none, and sy-subrc is the one of the
          // statement before
          let next = si + 1;
          while (seq[next] && kind(seq[next]) === "Comment") next++;
          if (seq[next] && kind(seq[next]) === "If" && /sy\s*-\s*subrc/i.test(renderTokens(seq[next].getTokens()))) {
            let depth = 0;
            for (let j = next; j < seq.length; j++) {
              const kj = kind(seq[j]);
              if (kj === "If") depth++;
              if (kj === "EndIf") depth--;
              this.alvPlan.set(seq[j], { action: "skip" });
              if (depth === 0) break;
            }
            plan.todos = [...(plan.todos ?? []), `${fm}: the IF sy-subrc after the call checked its EXCEPTIONS - alv( ) raises none, the check is dropped`];
          }
          continue;
        }
      }

      // the field catalog of REUSE_ALV_*: wa-fieldname = 'A', wa-seltext_m = 'T', APPEND wa TO fcat
      const fcatRoot = toks.length ? lc(toks[0]) : "";
      if (this.fcatVars.has(fcatRoot) || toks.some((t, i) => this.fcatVars.has(lc(t)) && (i === 0 || !["-", "->", "=>"].includes(toks[i - 1])))) {
        const m = /^([\w/]+)\s*-\s*(\w+)\s*=\s*(.+)$/.exec(flat);
        const orig = /^[\w/]+\s*-\s*\w+\s*=\s*(.+)$/.exec(toks.join(" "));
        if (k === "Move" && m && this.fcatVars.has(m[1])) {
          const cur = fcatWa.get(m[1]) ?? {};
          if (m[2] === "fieldname") cur.name = uc(unquote(orig[1].trim()));
          else if (/^(seltext_[lms]|reptext_ddic|scrtext_[lms]|coltext)$/.test(m[2])) cur.text = orig[1].trim();
          else if ((m[2] === "no_out" || m[2] === "tech") && /'x'|abap_true/.test(m[3])) cur.hidden = true;
          else this.note("field catalog settings without a counterpart (output length, key, sums, column position) - the grid takes columns and widths from the table");
          fcatWa.set(m[1], cur);
        } else if (k === "Append") {
          const m2 = /^append\s+([\w/]+)\s+to\s+([\w/]+)/.exec(flat);
          const v = /^append\s+value\s+#\s*\((.*)\)\s+to\s+([\w/]+)/i.exec(toks.join(" "));
          if (m2 && this.fcatVars.has(m2[2])) {
            if (!fcat.has(m2[2])) fcat.set(m2[2], []);
            fcat.get(m2[2]).push({ ...(fcatWa.get(m2[1]) ?? {}) });
          } else if (v && this.fcatVars.has(lc(v[2]))) {
            const cur = {};
            for (const p of v[1].matchAll(/(\w+)\s*=\s*('(?:[^']|'')*'|`(?:[^`]|``)*`|[\w-]+)/g)) {
              const comp = lc(p[1]);
              if (comp === "fieldname") cur.name = uc(unquote(p[2]));
              else if (/^(seltext_[lms]|reptext_ddic|scrtext_[lms]|coltext)$/.test(comp)) cur.text = p[2];
              else if ((comp === "no_out" || comp === "tech") && /'x'|abap_true/i.test(p[2])) cur.hidden = true;
            }
            if (!fcat.has(lc(v[2]))) fcat.set(lc(v[2]), []);
            fcat.get(lc(v[2])).push(cur);
          }
        } else if (k === "Clear") {
          for (const v of this.fcatVars) if (new RegExp(`\\b${v}\\b`).test(flat)) fcatWa.set(v, {});
        }
        this.alvPlan.set(s, { action: "drop", reason: "field catalog - set_column_text( ) / set_column_hidden( ) in the alv( ) chain" });
        continue;
      }
      if (toks.some((t, i) => this.layoutVars.has(lc(t)) && (i === 0 || !["-", "->", "=>"].includes(toks[i - 1]))) && k !== "CallFunction") {
        this.alvPlan.set(s, { action: "drop", reason: "ALV layout", todo: `ALV layout, sort or event setting without a counterpart, dropped: ${shortText(s)}` });
        continue;
      }

    }
    // a FORM that only built the field catalog or set up the ALV is empty now
    this.emptyForms = new Set(this.forms.filter((f) => {
      const code = f.body.filter((x) => kind(x) !== "Comment");
      return code.length > 0 && code.every((x) => ["drop", "skip"].includes(this.alvPlan.get(x)?.action));
    }).map((f) => lc(nodeText(child(f.stmt, "FormName")))));
    for (const [name, v] of this.salv) {
      if (!v.displayed) this.todo(v.stmt, `the CL_SALV_TABLE object ${name} is created but never displayed - no alv( ) is generated for it`);
    }
  }

  /** the selection screen: fields, value requests, user commands, HIDE */
  analyzeScreen() {
    this.valueRequest = new Set();
    for (const e of this.events) {
      if (e.kind !== "AtSelectionScreen") continue;
      const t = uc(renderTokens(stmtTokens(e.stmt)));
      const m = /ON\s+VALUE-REQUEST\s+FOR\s+([\w/]+)(-LOW|-HIGH)?/.exec(t);
      if (m) this.valueRequest.add(lc(m[1]));
    }
    this.screenUcomm = this.decls.some((s) => (kind(s) === "Parameter" && hasSeq(words(s), "USER", "-", "COMMAND"))
      || (kind(s) === "SelectionScreen" && words(s).includes("PUSHBUTTON")));
    const ass = this.events.filter((e) => e.kind === "AtSelectionScreen" && /^AT\s+SELECTION-SCREEN$/.test(uc(renderTokens(stmtTokens(e.stmt)))));
    this.assUcomm = ass.some((e) => e.stmts.some((s) => /\b(sy|sscrfields)\s*-\s*ucomm\b/i.test(renderTokens(s.getTokens()))));
  }

  // --------------------------------------------------------------- generate

  generate() {
    const cls = this.className;
    const pub = [];          // PUBLIC SECTION
    const methods = [];      // { name, def, body: string[] }
    this.methodDefs = [];    // PRIVATE methods
    this.redefined = new Set();
    this.tablesTypes = new Map();

    // the declarations: attributes, types, constants
    const screen = this.declarations(pub);

    // FORMs first - their method names are needed by every PERFORM
    for (const f of this.forms) {
      if (this.alvCallbacks.has(f.name) || this.emptyForms.has(f.name)) continue;
      this.formSignature(f);
    }

    // the event blocks
    const byKind = (k, pred = () => true) => this.events.filter((e) => e.kind === k && pred(e));
    const assText = (e) => uc(renderTokens(stmtTokens(e.stmt)));

    // INITIALIZATION: title, defaults, LOAD-OF-PROGRAM, INITIALIZATION
    {
      const body = [];
      if (this.pool.title) body.push(`set_title( ${literal(this.pool.title)} ).`);
      body.push(...screen.defaults);
      for (const e of [...byKind("LoadOfProgram"), ...byKind("Initialization")]) {
        this.map(e.stmt, "`initialization( )`");
        if (body.length) body.push("");
        body.push(...this.convertBody(e.stmts, { method: "initialization" }));
      }
      if (body.length) methods.push({ name: "initialization", body });
    }

    if (screen.chain.length) {
      methods.push({ name: "selection_screen", body: screen.chain });
    }

    // AT SELECTION-SCREEN OUTPUT
    {
      const evs = byKind("AtSelectionScreen", (e) => /OUTPUT$/.test(assText(e)));
      if (evs.length) {
        const body = [];
        for (const e of evs) {
          this.map(e.stmt, "`at_selection_screen_output( screen )`");
          body.push(...this.convertBody(e.stmts, { method: "at_selection_screen_output", screenEvent: true }));
        }
        methods.push({ name: "at_selection_screen_output", body });
      }
    }

    // AT SELECTION-SCREEN ON field, ON VALUE-REQUEST, ON ... (refused)
    const onField = [];
    const valueRequest = [];
    for (const e of byKind("AtSelectionScreen")) {
      const t = assText(e);
      if (/^AT\s+SELECTION-SCREEN(\s+OUTPUT)?$/.test(t)) continue;
      let m;
      if ((m = /ON\s+VALUE-REQUEST\s+FOR\s+([\w/]+)(-LOW|-HIGH)?$/.exec(t))) {
        const field = m[1];
        if (!this.screenField(field)) {
          this.refuse(e.stmt, `ON VALUE-REQUEST FOR ${field} - no parameter or select-option of that name`);
          continue;
        }
        if (valueRequest.some((v) => v.field === field)) {
          this.refuse(e.stmt, `a second ON VALUE-REQUEST for ${field} - a select-option has one F4 for LOW and HIGH here`);
          continue;
        }
        this.map(e.stmt, `\`at_value_request( field )\` - WHEN \`${field}\`, the field declared with value_help`);
        valueRequest.push({ field, body: this.convertBody(e.stmts, { method: "at_value_request", valueRequest: true }) });
      } else if (/ON\s+(HELP-REQUEST|BLOCK|RADIOBUTTON\s+GROUP|END\s+OF|EXIT-COMMAND)/.test(t)) {
        this.refuse(e.stmt, `${t.replace(/^AT\s+SELECTION-SCREEN\s+/, "AT SELECTION-SCREEN ")} - not supported by abap-cloud-gui (roadmap); check it in at_selection_screen( ) instead`);
      } else if ((m = /ON\s+([\w/]+)$/.exec(t))) {
        const field = m[1];
        if (!this.screenField(field)) {
          this.refuse(e.stmt, `ON ${field} - no parameter or select-option of that name`);
          continue;
        }
        this.map(e.stmt, `\`at_selection_screen_on( field )\` - WHEN \`${field}\``);
        onField.push({ field, body: this.convertBody(e.stmts, { method: "at_selection_screen_on" }) });
      }
    }
    if (onField.length) {
      methods.push({ name: "at_selection_screen_on", body: caseBody("field", onField) });
    }

    // AT SELECTION-SCREEN
    const ass = byKind("AtSelectionScreen", (e) => /^AT\s+SELECTION-SCREEN$/.test(assText(e)));
    if (ass.length) {
      const body = [];
      for (const e of ass) {
        this.map(e.stmt, this.assUcomm
          ? "`at_selection_screen( )` and `at_user_command( )` - both call `at_selection_screen_ucomm( ucomm )`, sy-ucomm becomes ucomm"
          : "`at_selection_screen( )`");
        body.push(...this.convertBody(e.stmts, { method: "at_selection_screen", ucomm: this.assUcomm }));
      }
      if (this.assUcomm) {
        this.methodDefs.push({ name: "at_selection_screen_ucomm", lines: ["    METHODS at_selection_screen_ucomm", "      IMPORTING", "        ucomm TYPE string."] });
        methods.push({ name: "at_selection_screen", body: ["\" F8 - the classic sy-ucomm of Execute", "at_selection_screen_ucomm( `ONLI` )."] });
        this.privateMethods = [...(this.privateMethods ?? []), { name: "at_selection_screen_ucomm", body }];
      } else {
        methods.push({ name: "at_selection_screen", body });
      }
    }

    // TOP-OF-PAGE - written once at the start of the list and after NEW-PAGE
    const top = byKind("TopOfPage");
    this.topOfPage = false;
    if (top.length) {
      const e = top[0];
      const words0 = uc(renderTokens(stmtTokens(e.stmt)));
      const output = new Set(["Write", "Uline", "Skip", "NewLine", "Format", "Comment"]);
      const bad = e.stmts.find((s) => !output.has(kind(s)));
      if (/DURING/.test(words0)) {
        this.refuse(e.stmt, "TOP-OF-PAGE DURING LINE-SELECTION - secondary lists have no page header");
      } else if (bad) {
        this.refuse(bad, "TOP-OF-PAGE with other statements than WRITE, ULINE, SKIP, NEW-LINE and FORMAT - the list has no page header; only a fixed header is converted");
      } else {
        this.topOfPage = true;
        this.map(e.stmt, "private method `top_of_page( )`, called at the start of `start_of_selection( )` and after each NEW-PAGE");
        this.todo(e.stmt, "TOP-OF-PAGE: the header is written once at the start of the list and after each NEW-PAGE - not at every page break; sy-pagno is not set");
        this.methodDefs.push({ name: "top_of_page", lines: ["    METHODS top_of_page."] });
        this.privateMethods = [...(this.privateMethods ?? []), { name: "top_of_page", body: this.convertBody(e.stmts, { method: "top_of_page" }) }];
      }
      for (const more of top.slice(1)) this.refuse(more.stmt, "a second TOP-OF-PAGE");
    }

    // START-OF-SELECTION + END-OF-SELECTION
    {
      const body = [];
      if (this.topOfPage) body.push("top_of_page( ).");
      for (const e of byKind("StartOfSelection")) {
        if (!e.implicit) this.map(e.stmt, "`start_of_selection( )`");
        else this.map(e.stmt, "`start_of_selection( )` - statements before the first event block");
        if (body.length) body.push("");
        body.push(...this.convertBody(e.stmts, { method: "start_of_selection" }));
      }
      for (const e of byKind("EndOfSelection")) {
        this.map(e.stmt, "appended to `start_of_selection( )`");
        body.push("", "\" END-OF-SELECTION");
        body.push(...this.convertBody(e.stmts, { method: "start_of_selection" }));
      }
      if (body.length) methods.push({ name: "start_of_selection", body });
    }

    // AT LINE-SELECTION: HIDE restored first, the ALV double click callback
    {
      const evs = byKind("AtLineSelection");
      const callback = this.forms.find((f) => this.alvCallbacks.get(f.name)?.kind === "user_command");
      if (evs.length || callback) {
        const body = [];
        const deferred = () => this.hideRestore();
        for (const e of evs) {
          this.map(e.stmt, "`at_line_selection( row hide )` - HIDE fields restored from `hide`");
          body.push(...this.convertBody(e.stmts, { method: "at_line_selection", lineSelection: true }));
        }
        if (callback) {
          body.push(...this.alvCallbackBody(callback));
        }
        methods.push({ name: "at_line_selection", body, prelude: deferred });
      }
    }

    // AT USER-COMMAND
    {
      const evs = byKind("AtUserCommand");
      if (evs.length || this.assUcomm) {
        const body = [];
        if (this.assUcomm) body.push("\" a button or USER-COMMAND of the selection screen - the classic AT SELECTION-SCREEN", "at_selection_screen_ucomm( ucomm ).");
        for (const e of evs) {
          this.map(e.stmt, "`at_user_command( ucomm )` - sy-ucomm becomes ucomm");
          if (this.assUcomm) this.todo(e.stmt, "AT USER-COMMAND and the user commands of the selection screen both arrive in at_user_command( ) - check that the codes do not overlap");
          if (body.length) body.push("");
          body.push(...this.convertBody(e.stmts, { method: "at_user_command", userCommand: true }));
        }
        methods.push({ name: "at_user_command", body });
      }
    }

    // AT SELECTION-SCREEN ON VALUE-REQUEST
    if (valueRequest.length) {
      const body = ["CASE field."];
      for (const v of valueRequest) body.push(`  WHEN ${literal(v.field)}.`, ...v.body.map((l) => indent(l, 4)));
      body.push("  WHEN OTHERS.", "    super->at_value_request( field ).", "ENDCASE.");
      methods.push({ name: "at_value_request", body });
    }

    // FORMs
    const formMethods = [];
    for (const f of this.forms) {
      if (this.alvCallbacks.has(f.name)) {
        const cb = this.alvCallbacks.get(f.name);
        if (cb.kind !== "user_command") {
          this.todo(f.stmt, `FORM ${f.name} is the ${uc(cb.kind)} callback of the ALV - no counterpart, not converted`);
        }
        continue;
      }
      if (this.emptyForms.has(f.name)) {
        for (const x of f.body) this.statement(x, { out: [], ctx: { method: f.method }, line: [], loopDepth: 0, screenLoopDepth: -1 });
        this.map(f.stmt, "dropped - the FORM only set up the ALV, which the alv( ) chain does now");
        continue;
      }
      this.map(f.stmt, `private method \`${f.method}( )\``);
      formMethods.push({ name: f.method, body: this.convertBody(f.body, { method: f.method, form: f }) });
    }
    for (const f of this.forms) {
      if (!this.alvCallbacks.has(f.name) && !this.emptyForms.has(f.name) && !f.performed) this.todo(f.stmt, `FORM ${f.name} is not PERFORMed in this report - the private method ${f.method}( ) is unused (abaplint unused_methods)`);
    }

    // the selection screen takes its value helps from the screen pass above
    const restore = methods.find((m) => m.prelude);
    if (restore) {
      const pre = restore.prelude();
      if (pre.length) restore.body.unshift(...pre, "");
    }

    for (const m of methods) this.redefined.add(m.name);

    // ------------------------------------------------------------ class text
    const lines = [];
    lines.push(`CLASS ${cls} DEFINITION PUBLIC`);
    lines.push("  INHERITING FROM z2ui5_cl_cgui_report");
    lines.push("  FINAL");
    lines.push("  CREATE PUBLIC.");
    lines.push("");
    lines.push("  PUBLIC SECTION.");
    lines.push(...pub.map((l) => indent(l, 4)));
    lines.push("");
    lines.push("  PROTECTED SECTION.");
    const order = ["initialization", "selection_screen", "at_selection_screen_output", "at_selection_screen_on",
      "at_selection_screen", "start_of_selection", "at_line_selection", "at_user_command", "at_value_request"];
    methods.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));
    for (const m of methods) lines.push(`    METHODS ${m.name} REDEFINITION.`);
    lines.push("");
    lines.push("  PRIVATE SECTION.");
    for (const t of this.tablesTypes.values()) lines.push(`    ${t}`);
    if (this.tablesTypes.size && this.methodDefs.length) lines.push("");
    this.methodDefs.forEach((d, i) => {
      if (i > 0) lines.push("");
      lines.push(...d.lines);
    });
    lines.push("ENDCLASS.");
    lines.push("");
    lines.push("");
    lines.push(`CLASS ${cls} IMPLEMENTATION.`);
    const impl = [...methods, ...(this.privateMethods ?? []), ...formMethods];
    for (const m of impl) {
      lines.push("");
      lines.push(`  METHOD ${m.name}.`);
      lines.push("");
      const was = [...(this.methodWa.get(m.name) ?? new Map())].map(([tab, wa]) => `DATA ${wa} LIKE LINE OF ${tab}.`);
      const globalFs = [...was, ...(this.prelude.get(m.name) ?? []), ...this.fieldSymbolDecls(m.body)];
      for (const l of [...globalFs, ...(globalFs.length ? [""] : []), ...trimBlank(m.body)]) lines.push(indent(l, 4));
      lines.push("");
      lines.push("  ENDMETHOD.");
    }
    lines.push("");
    lines.push("ENDCLASS.");

    let abap = normalizeAbap(this.reindent(lines.join("\n"), `${cls}.clas.abap`));
    const files = { [`${cls}.clas.abap`]: abap };

    // local classes and interfaces
    const locals = this.localsSource();
    if (locals.def) files[`${cls}.clas.locals_def.abap`] = normalizeAbap(locals.def);
    if (locals.imp) files[`${cls}.clas.locals_imp.abap`] = normalizeAbap(locals.imp);

    files[`${cls}.clas.xml`] = classXml(cls, this.pool.title || `report2cloud - ${this.programName}`);

    for (const [name, text] of Object.entries(files)) {
      for (const l of longLines(text)) {
        this.todos.push({ row: 0, col: 0, file: name, message: `${name}:${l.row} is ${l.length} characters long - abapGit imports at most 255; split the line` });
      }
    }

    const release = this.releaseTodos(files);
    if (screen.lowerCase) this.note("character parameters without LOWER CASE: the classic screen converted the input to upper case, the UI5 input does not - add to_upper( ) where the case matters");
    return {
      className: cls,
      programName: this.programName,
      file: this.file,
      files: this.refusals.length ? {} : files,
      draft: files,
      refusals: this.refusals.sort((a, b) => a.row - b.row || a.col - b.col),
      mapped: this.mapped.sort((a, b) => a.row - b.row || a.col - b.col),
      todos: this.todos.filter((t, i, all) => all.findIndex((x) => x.row === t.row && x.col === t.col && x.message === t.message) === i)
        .sort((a, b) => a.row - b.row || a.col - b.col),
      release,
      notes: [...this.notes.entries()].map(([text, count]) => ({ text, count })),
      ok: this.refusals.length === 0,
    };
  }

  screenField(name) {
    return this.screenFields?.has(lc(name));
  }

  // ----------------------------------------------------------- declarations

  /** the PUBLIC SECTION lines, the chain of selection_screen( ) and the
   *  defaults initialization( ) sets */
  declarations(pub) {
    const chain = [];       // { method, params: [{ name, value }], positional }
    const defaults = [];
    const radioGroups = new Map();
    const fieldTexts = [];
    let lowerCase = false;
    this.screenFields = new Set();
    // three groups, in this order: what a declaration may refer to comes first
    const sections = { types: [], data: [], screen: [] };
    let target = sections.data;
    const heading = (h) => {
      target = h === "selection screen" ? sections.screen : /types|constants/.test(h) ? sections.types : sections.data;
    };
    const push = (line) => target.push(line);
    for (let i = 0; i < this.decls.length; i++) {
      const s = this.decls[i];
      const k = kind(s);
      const w = words(s);

      if (k === "Parameter") {
        const name = lc(nodeText(child(s, "FieldSub")));
        this.screenFields.add(name);
        const checkbox = hasSeq(w, "AS", "CHECKBOX");
        const radio = w.includes("RADIOBUTTON");
        const ucomm = this.userCommand(s);
        const modif = child(s, "Modif");
        const noDisplay = hasSeq(w, "NO", "-", "DISPLAY");
        const params = [{ name: "val", value: name }];
        const text = this.selectionText(name, s, fieldTexts);
        if (text) params.push({ name: "text", value: text });
        let method = "parameter";
        if (checkbox && !noDisplay) method = "checkbox";
        if (radio) {
          method = "radiobutton";
          const group = uc(nodeText(child(s, "RadioGroupName")));
          params.push({ name: "group", value: literal(group) });
          if (!radioGroups.has(group)) radioGroups.set(group, { first: name, defaulted: false, stmt: s });
        }
        if (w.includes("OBLIGATORY") && method === "parameter") params.push({ name: "obligatory", value: "abap_true" });
        if (this.valueRequest.has(name) && method === "parameter") params.push({ name: "value_help", value: "abap_true" });
        if (modif) params.push({ name: "modif_id", value: literal(uc(nodeText(modif))) });
        if (ucomm && method !== "parameter") params.push({ name: "user_command", value: literal(ucomm) });
        if (noDisplay) params.push({ name: "no_display", value: "abap_true" });
        chain.push({ method, params });

        heading("selection screen");
        const type = checkbox || radio ? "TYPE abap_bool" : this.parameterType(s);
        push(`DATA ${name} ${type}.`);
        if (!checkbox && !radio && !w.includes("LOWER") && /TYPE c\b|TYPE c LENGTH|TYPE string/.test(type)) lowerCase = true;

        const def = after(s, "DEFAULT");
        if (def) {
          let value = nodeText(def, this.rewrites(s, {}));
          if (checkbox || radio) {
            if (/^'X'$|^`X`$/i.test(value)) value = "abap_true";
            else value = undefined;
            if (radio && value) radioGroups.get(uc(nodeText(child(s, "RadioGroupName")))).defaulted = true;
          } else if (/^(space|' '|``|'')$/i.test(value)) value = undefined;
          if (value) defaults.push(`${name} = ${value}.`);
        }

        const parts = [`attribute \`${name}\``, `\`screen->${method}( )\``];
        if (w.includes("MATCHCODE")) this.todo(s, `MATCHCODE OBJECT of ${uc(name)}: search helps are not supported - answer F4 in at_value_request( ) with value_help_popup( )`);
        if (hasSeq(w, "MEMORY", "ID")) this.todo(s, `MEMORY ID of ${uc(name)}: SET/GET PARAMETER is not supported - the field starts empty (or with its DEFAULT)`);
        if (hasSeq(w, "VALUE", "CHECK")) this.todo(s, `VALUE CHECK of ${uc(name)}: the input is not checked against the value table - check it in at_selection_screen_on( )`);
        if (hasSeq(w, "AS", "LISTBOX")) this.todo(s, `AS LISTBOX of ${uc(name)}: shown as an input with F4 - the domain's fixed values come up as standard F4`);
        if (w.includes("VISIBLE")) this.note("VISIBLE LENGTH - the input takes the width of the form");
        this.map(s, parts.join(", "));
        continue;
      }

      if (k === "SelectOption") {
        const name = lc(nodeText(child(s, "FieldSub")));
        this.screenFields.add(name);
        const forNode = after(s, "FOR");
        const forText = lc(nodeText(forNode));
        const params = [{ name: "val", value: name }];
        const text = this.selectionText(name, s, fieldTexts);
        if (text) params.push({ name: "text", value: text });
        if (w.includes("OBLIGATORY")) params.push({ name: "obligatory", value: "abap_true" });
        if (this.valueRequest.has(name)) params.push({ name: "value_help", value: "abap_true" });
        const modif = child(s, "Modif");
        if (modif) params.push({ name: "modif_id", value: literal(uc(nodeText(modif))) });
        if (hasSeq(w, "NO", "-", "DISPLAY")) params.push({ name: "no_display", value: "abap_true" });
        chain.push({ method: "select_option", params });

        heading("selection screen");
        const root = forText.split("-")[0];
        const like = this.globalData.has(root) && (!this.isTables(root) || this.tablesKept.has(root));
        push(`DATA ${name} ${like ? "LIKE" : "TYPE"} RANGE OF ${forText}.`);

        const defNode = after(s, "DEFAULT");
        if (defNode) {
          const ov = this.rewrites(s, {});
          const low = nodeText(defNode, ov);
          const toNode = after(s, "TO");
          const high = toNode ? nodeText(toNode, ov) : undefined;
          const optIdx = w.indexOf("OPTION");
          const signIdx = w.indexOf("SIGN");
          const tokensAfter = (word) => {
            const ch = s.getChildren();
            const at = ch.findIndex((c) => isToken(c) && uc(c.get().getStr()) === word);
            return at >= 0 ? uc(ch[at + 1].getFirstToken().getStr()) : undefined;
          };
          const option = optIdx >= 0 ? tokensAfter("OPTION") : (high ? "BT" : "EQ");
          const sign = signIdx >= 0 ? tokensAfter("SIGN") : "I";
          defaults.push(`${name} = VALUE #( ( sign = ${literal(sign)} option = ${literal(option)} low = ${low}${high ? ` high = ${high}` : ""} ) ).`);
        }
        if (hasSeq(w, "NO", "INTERVALS") || hasSeq(w, "NO", "-", "EXTENSION")) {
          this.todo(s, `NO INTERVALS / NO-EXTENSION of ${uc(name)}: the select-option offers intervals and multiple selection - check the lines in at_selection_screen_on( ) if the report relies on a single value`);
        }
        if (w.includes("MATCHCODE")) this.todo(s, `MATCHCODE OBJECT of ${uc(name)}: search helps are not supported - answer F4 in at_value_request( )`);
        if (hasSeq(w, "MEMORY", "ID")) this.todo(s, `MEMORY ID of ${uc(name)}: SET/GET PARAMETER is not supported`);
        this.map(s, `range attribute \`${name}\`, \`screen->select_option( )\``);
        continue;
      }

      if (k === "SelectionScreen") {
        this.selectionScreen(s, chain, push, heading);
        continue;
      }

      if (k === "Tables") {
        const name = lc(declName(s));
        if (name === "sscrfields") {
          this.map(s, this.assUcomm ? "dropped - sscrfields-ucomm is the ucomm of at_selection_screen_ucomm( )" : "dropped");
          continue;
        }
        if (this.tablesKept.has(name)) {
          heading("global data of the report");
          push(`DATA ${name} TYPE ${name}.`);
          this.map(s, `typed work area \`DATA ${name} TYPE ${name}\``);
          this.todo(s, `TABLES ${name} is now a work area of type ${uc(name)} - on ABAP Cloud the table must be replaced by a released CDS view (see the release TODOs)`);
        } else {
          this.map(s, "dropped - it only typed the select-options and parameters, which now refer to the DDIC type");
        }
        continue;
      }

      if (k === "TypePools" || k === "TypePool") {
        this.map(s, "dropped - type pools load by themselves");
        continue;
      }

      if (k === "FieldSymbol") {
        // a global field-symbol is declared in every method that uses it
        this.globalFieldSymbols = [...(this.globalFieldSymbols ?? []), s];
        this.map(s, "declared in each method that uses it");
        continue;
      }

      if (REFUSED[k]) {
        this.refuse(s, REFUSED[k]);
        continue;
      }

      if (k === "Data" || k === "DataBegin" || k === "DataEnd" || k === "Type" || k === "TypeBegin" || k === "TypeEnd"
        || k === "Constant" || k === "ConstantBegin" || k === "ConstantEnd" || k === "IncludeType" || k === "Ranges"
        || k === "TypeEnum" || k === "TypeEnumBegin" || k === "TypeEnumEnd") {
        const isType = /^Type/.test(k) || k === "IncludeType";
        const isConst = /^Constant/.test(k);
        const name = lc(declName(s) ?? "");
        if ((k === "Data") && (this.salvVars.has(name) || this.fcatVars.has(name) || this.layoutVars.has(name)) && !this.insideBegin(s)) {
          this.map(s, "dropped - the ALV object, field catalog or layout is the alv( ) chain now");
          continue;
        }
        if (k === "Data" && GUI_CONTROL.test(lc(renderTokens(stmtTokens(s))))) {
          this.refuse(s, "SAP GUI controls (cl_gui_*) need a dynpro container - use alv( ) or an abap2UI5 view");
          continue;
        }
        if (k === "Data" || k === "DataBegin") {
          const t = uc(renderTokens(stmtTokens(s)));
          if (/\bOCCURS\b|WITH\s+HEADER\s+LINE/.test(t)) {
            this.refuse(s, "a table with a header line (OCCURS / WITH HEADER LINE) - not allowed in classes; declare the table and a work area of its own");
            continue;
          }
        }
        heading(isType ? "types of the report" : isConst ? "constants of the report" : "global data of the report");
        if (k === "Ranges") {
          const forNode = child(s, "SimpleFieldChain2");
          const forText = lc(nodeText(forNode));
          const root = forText.split("-")[0];
          const like = this.globalData.has(root) && (!this.isTables(root) || this.tablesKept.has(root));
          push(`DATA ${name} ${like ? "LIKE" : "TYPE"} RANGE OF ${forText}.`);
          this.map(s, `\`DATA ${name} ... RANGE OF\``);
          continue;
        }
        if (s.getColon()) {
          const group = [s];
          while (this.decls[i + 1] && sameColon(this.decls[i + 1], s)) group.push(this.decls[++i]);
          const text = this.renderDeclGroup(group);
          if (text) push(text);
        } else {
          push(this.renderDecl(s));
        }
        continue;
      }

      if (k === "StaticBegin" || k === "StaticEnd" || k === "Static") {
        this.refuse(s, "STATICS outside of a FORM - use DATA");
        continue;
      }
    }

    // radio button groups: the first button is selected unless one has DEFAULT 'X'
    for (const [, g] of radioGroups) {
      if (!g.defaulted) defaults.unshift(`${g.first} = abap_true.`);
    }
    if (fieldTexts.length) {
      this.todos.push({ row: 0, col: 0, message: `no selection text in the text pool for ${fieldTexts.join(", ")} - the label is the DDIC label of the type or the field name; pass the .prog.xml (--texts) or set text = in selection_screen( )` });
    }

    for (const list of Object.values(sections)) alignData(list);
    const blocks = [["types and constants of the report", sections.types], ["global data of the report", sections.data],
      ["selection screen", sections.screen]];
    for (const [title, list] of blocks) {
      if (!list.length) continue;
      if (pub.length) pub.push("");
      pub.push(`" ${title}`, ...list);
    }
    return { chain: renderScreenChain(chain), defaults, lowerCase };
  }

  isTables(name) {
    return this.decls.some((s) => kind(s) === "Tables" && lc(declName(s)) === name);
  }

  userCommand(s) {
    const ch = s.getChildren();
    for (let i = 0; i < ch.length - 3; i++) {
      if (isToken(ch[i]) && uc(ch[i].get().getStr()) === "USER" && uc(ch[i + 2].getFirstToken().getStr()) === "COMMAND") {
        return uc(ch[i + 3].getFirstToken().getStr());
      }
    }
    return undefined;
  }

  selectionText(name, s, missing) {
    const t = this.pool.selection.get(uc(name));
    if (t) return literal(t);
    if (t === null) return undefined;     // from the DDIC
    missing.push(uc(name));
    return undefined;
  }

  textSymbol(keyText, fallback, at) {
    const t = this.pool.symbols.get(uc(keyText));
    if (t !== undefined) return literal(t);
    if (fallback !== undefined) return literal(fallback);
    this.todo(at, `text symbol TEXT-${uc(keyText)} is not in the text pool - the generated literal \`TEXT-${uc(keyText)}\` needs the real text`);
    return literal(`TEXT-${uc(keyText)}`);
  }

  parameterType(s) {
    const len = child(s, "ConstantFieldLength");
    let length = len ? nodeText(child(len, "Integer")) : undefined;
    const ch = s.getChildren();
    let typeWord;
    let typeNode;
    for (let i = 0; i < ch.length; i++) {
      if (isToken(ch[i]) && ["TYPE", "LIKE"].includes(uc(ch[i].get().getStr())) && ch[i + 1] && !isToken(ch[i + 1])) {
        typeWord = uc(ch[i].get().getStr());
        typeNode = ch[i + 1];
        break;
      }
    }
    const dec = after(s, "DECIMALS");
    const decimals = dec ? ` DECIMALS ${nodeText(dec)}` : "";
    if (!typeNode) return `TYPE c LENGTH ${length ?? 1}`;
    // TYPE c LENGTH 10 - the LENGTH right after the type, not VISIBLE LENGTH
    const at = ch.indexOf(typeNode);
    if (!length && ch[at + 1] && isToken(ch[at + 1]) && uc(ch[at + 1].get().getStr()) === "LENGTH" && ch[at + 2]) {
      length = nodeText(ch[at + 2]);
    }
    const t = lc(nodeText(typeNode));
    if (typeWord === "LIKE") {
      const root = t.split("-")[0];
      const like = this.globalData.has(root) && (!this.isTables(root) || this.tablesKept.has(root));
      return `${like ? "LIKE" : "TYPE"} ${t}`;
    }
    if (["c", "n", "x", "p"].includes(t) && length) return `TYPE ${t} LENGTH ${length}${decimals}`;
    if (t === "c" && !length) return "TYPE c LENGTH 1";
    return `TYPE ${t}${decimals}`;
  }

  selectionScreen(s, chain, push, heading) {
    const w = words(s);
    const textOf = (node) => {
      if (!node) return undefined;
      if (kind(node) === "TextElement") return this.textSymbol(nodeText(child(node, "TextElementKey")), undefined, s);
      return undefined;
    };
    const textElement = child(s, "TextElement");
    const inline = child(s, "InlineField");
    // a COMMENT, PUSHBUTTON or block TITLE with a field name instead of a
    // text symbol declares that field - the report sets it in INITIALIZATION
    const fieldText = (len) => {
      const name = lc(nodeText(inline));
      heading("selection screen");
      push(`DATA ${name} TYPE ${len ? `c LENGTH ${len}` : "string"}.`);
      return name;
    };
    const lengthOf = () => {
      const int = child(s, "Integer");
      return int ? nodeText(int) : undefined;
    };
    const modif = child(s, "Modif");

    if (hasSeq(w, "BEGIN", "OF", "BLOCK")) {
      let title;
      if (w.includes("TITLE")) title = textOf(textElement) ?? (inline ? fieldText(undefined) : undefined);
      chain.push({ method: "block_begin", params: title ? [{ value: title }] : [], positional: true });
      if (hasSeq(w, "NO", "INTERVALS")) this.note("SELECTION-SCREEN BEGIN OF BLOCK ... NO INTERVALS - select-options show both fields");
      this.map(s, "`screen->block_begin( )`");
    } else if (hasSeq(w, "END", "OF", "BLOCK")) {
      chain.push({ method: "block_end", params: [] });
      this.map(s, "`screen->block_end( )`");
    } else if (hasSeq(w, "BEGIN", "OF", "LINE")) {
      chain.push({ method: "line_begin", params: [] });
      this.map(s, "`screen->line_begin( )`");
    } else if (hasSeq(w, "END", "OF", "LINE")) {
      chain.push({ method: "line_end", params: [] });
      this.map(s, "`screen->line_end( )`");
    } else if (w.includes("COMMENT")) {
      const text = textOf(textElement) ?? (inline ? fieldText(lengthOf()) : literal(""));
      // the comment that opens a line FOR FIELD is the label of the line
      const prev = chain[chain.length - 1];
      if (hasSeq(w, "FOR", "FIELD") && !modif && prev?.method === "line_begin" && !prev.params.length) {
        prev.params.push({ value: text });
        prev.positional = true;
        this.map(s, "the label of `screen->line_begin( )`");
        return;
      }
      const params = [{ name: "text", value: text }];
      if (modif) params.push({ name: "modif_id", value: literal(uc(nodeText(modif))) });
      chain.push({ method: "comment", params, positional: !modif });
      this.map(s, "`screen->comment( )`");
    } else if (w.includes("PUSHBUTTON")) {
      const text = textOf(textElement) ?? (inline ? fieldText(lengthOf()) : literal(""));
      const ucommNode = after(s, "COMMAND");
      const params = [{ name: "text", value: text }];
      const ucomm = this.userCommand(s) ?? (ucommNode ? uc(nodeText(ucommNode)) : "");
      params.push({ name: "event", value: literal(ucomm) });
      if (modif) params.push({ name: "modif_id", value: literal(uc(nodeText(modif))) });
      chain.push({ method: "button", params });
      this.map(s, "`screen->button( )` - its USER-COMMAND arrives in `at_user_command( )`");
    } else if (w.includes("SKIP") || w.includes("ULINE") || w.includes("POSITION")) {
      this.map(s, "dropped - the selection screen has no blank lines, lines or positions");
      this.note("SELECTION-SCREEN SKIP / ULINE / POSITION - the form lays out the fields by itself");
    } else if (hasSeq(w, "FUNCTION", "KEY")) {
      this.refuse(s, "SELECTION-SCREEN FUNCTION KEY - the selection screen has no toolbar functions; use a PUSHBUTTON (screen->button( ))");
    } else if (hasSeq(w, "BEGIN", "OF", "SCREEN") || hasSeq(w, "END", "OF", "SCREEN")) {
      this.refuse(s, "SELECTION-SCREEN BEGIN OF SCREEN - only the standard selection screen is converted");
    } else if (w.includes("TABBED") || w.includes("TAB")) {
      this.refuse(s, "SELECTION-SCREEN TABBED BLOCK / TAB - tabstrips on the selection screen are not supported");
    } else if (w.includes("INCLUDE")) {
      this.refuse(s, "SELECTION-SCREEN INCLUDE - the included selection screen is not part of the input");
    } else if (w.includes("DYNAMIC")) {
      this.refuse(s, "SELECTION-SCREEN DYNAMIC SELECTIONS - logical database selections");
    } else {
      this.refuse(s, `this SELECTION-SCREEN statement is not supported: ${shortText(s)}`);
    }
  }

  /** a global declaration as an attribute: LIKE a DDIC field becomes TYPE */
  renderDecl(s) {
    const ov = this.rewrites(s, {});
    this.likeToType(s, ov);
    const t = renderTokens(stmtTokens(s), ov, s.getColon()).replace(/^(\w+)(\s*):\s*/, "$1 ");
    const k = kind(s);
    if (k === "DataBegin" || k === "TypeBegin" || k === "ConstantBegin" || k === "TypeEnumBegin") return `${t}.`;
    return `${t}.`;
  }

  /** a chained declaration in the house layout:
   *    TYPES:
   *      BEGIN OF ty_s_flight,
   *        carrid TYPE c LENGTH 3,
   *      END OF ty_s_flight. */
  renderDeclGroup(all) {
    const keyword = uc(all[0].getFirstToken().getStr());
    const group = all.filter((s) => {
      const name = lc(declName(s) ?? "");
      const alv = kind(s) === "Data" && (this.salvVars.has(name) || this.fcatVars.has(name) || this.layoutVars.has(name));
      if (alv) this.map(s, "dropped - the ALV object, field catalog or layout is the alv( ) chain now");
      return !alv;
    });
    if (!group.length) return undefined;
    if (group.length === 1 && !/Begin$|End$/.test(kind(group[0]))) return this.renderDecl(group[0]);
    const lines = [`${keyword}:`];
    let depth = 1;
    group.forEach((s, i) => {
      const k = kind(s);
      if (/End$/.test(k)) depth--;
      const ov = this.rewrites(s, {});
      this.likeToType(s, ov);
      const part = renderTokens(partTokens(s), ov);
      lines.push(`${"  ".repeat(depth)}${part.replace(/\n/g, `\n${"  ".repeat(depth)}`)}${i === group.length - 1 ? "." : ","}`);
      if (/Begin$/.test(k)) depth++;
    });
    return lines.join("\n");
  }

  likeToType(s, ov) {
    const toks = stmtTokens(s);
    for (let i = 0; i < toks.length - 1; i++) {
      if (uc(toks[i].getStr()) !== "LIKE") continue;
      if (["LINE", "RANGE", "REF", "STANDARD", "SORTED", "HASHED", "TABLE"].includes(uc(toks[i + 1].getStr()))) continue;
      const root = lc(toks[i + 1].getStr());
      const isData = this.globalData.has(root) && (!this.isTables(root) || this.tablesKept.has(root));
      const isLocal = this.currentLocals?.has(root);
      const isParam = this.currentForm?.params.some((p) => p.name === root);
      if (!isData && !isLocal && !isParam && toks[i + 2]?.getStr() === "-") ov.set(key(toks[i]), "TYPE");
    }
  }

  // --------------------------------------------------------------- FORMs

  formSignature(f) {
    this.currentForm = f;
    const imp = [];
    const chg = [];
    for (const p of f.params) {
      const node = p.node;
      let type;
      const ft = child(node, "FormParamType");
      const structure = after(node, "STRUCTURE");
      if (ft) {
        const ov = new Map();
        const toks = ft.getTokens();
        if (uc(toks[0].getStr()) === "LIKE" && toks[1]) {
          const root = lc(toks[1].getStr());
          const isData = this.globalData.has(root) && (!this.isTables(root) || this.tablesKept.has(root));
          if (!isData && !["line", "range", "ref"].includes(root)) ov.set(key(toks[0]), "TYPE");
        }
        type = renderTokens(toks, ov).replace(/\s+/g, " ");
        if (p.kind === "tables" && !/TABLE/i.test(type)) {
          type = this.tablesType(type.replace(/^(TYPE|LIKE)\s+/i, ""), /^LIKE/i.test(type));
        }
      } else if (structure) {
        const name = lc(nodeText(structure));
        const isData = this.globalData.has(name.split("-")[0]) && (!this.isTables(name) || this.tablesKept.has(name));
        type = p.kind === "tables" ? this.tablesType(name, isData) : `${isData ? "LIKE" : "TYPE"} ${name}`;
      } else {
        type = p.kind === "tables" ? "TYPE STANDARD TABLE" : "TYPE any";
        if (p.kind !== "tables") this.todo(f.stmt, `FORM ${f.name}: the parameter ${p.name} has no type - TYPE any, give it the type it has`);
      }
      p.type = type;
      if (p.kind === "using" && !p.written) imp.push(`${p.byValue ? `VALUE(${p.name})` : p.name} ${type}`);
      else if (p.kind === "using" && p.byValue) imp.push(`VALUE(${p.name}) ${type}`);
      else {
        if (p.kind === "using") p.promoted = true;
        chg.push(`${p.byValue ? `VALUE(${p.name})` : p.name} ${type}`);
      }
      if (p.kind === "tables") this.checkHeaderLine(f, p);
    }
    const lines = [`    METHODS ${f.method}`];
    const section = (title, list) => {
      if (!list.length) return;
      lines.push(`      ${title}`);
      const width = Math.max(...list.map((l) => l.split(" ")[0].length));
      for (const l of list) {
        const [n, ...rest] = l.split(" ");
        lines.push(`        ${n.padEnd(width)} ${rest.join(" ")}`);
      }
    };
    section("IMPORTING", imp);
    section("CHANGING", chg);
    if (f.raising.length) {
      lines.push("      RAISING");
      for (const r of f.raising) lines.push(`        ${r}`);
    }
    lines[lines.length - 1] += ".";
    this.methodDefs.push({ name: f.method, lines });
    this.currentForm = undefined;
  }

  tablesType(structure, isData) {
    const name = `ty_t_${structure.replace(/[^a-z0-9_]/gi, "_")}`.slice(0, 30);
    if (!this.tablesTypes.has(name)) {
      this.tablesTypes.set(name, `TYPES ${name} ${isData ? "LIKE" : "TYPE"} STANDARD TABLE OF ${structure} WITH DEFAULT KEY.`);
    }
    return `TYPE ${name}`;
  }

  checkHeaderLine(f, p) {
    for (const s of f.body) {
      const toks = stmtTokens(s).map((t) => lc(t.getStr()));
      const k = kind(s);
      const idx = toks.indexOf(p.name);
      if (idx < 0) continue;
      const next = toks[idx + 1];
      const prev = toks[idx - 1];
      const headerUse = (next === "-" && prev !== "-" && prev !== "->")
        || (k === "Loop" && !toks.some((t) => ["into", "assigning", "reference", "transporting"].includes(t)))
        || (k === "Append" && toks.length === 2)
        || (k === "ReadTable" && !toks.some((t) => ["into", "assigning", "reference", "transporting"].includes(t)));
      if (headerUse) {
        this.refuse(s, `the TABLES parameter ${p.name} of FORM ${f.name} is used with its header line - a method has none; give the FORM a work area of its own first`);
        return;
      }
    }
  }

  // ---------------------------------------------------------------- bodies

  /** the statements of an event block or FORM as the lines of a method */
  convertBody(stmts, ctx) {
    const b = {
      out: [],                    // lines (strings) and write chains (objects)
      ctx,
      color: "none",
      hotspot: false,
      line: [],                   // the write items of the current list line
      msgDeclared: false,
      loopDepth: 0,
      screenLoopDepth: -1,
      screenWa: undefined,
      lastRow: undefined,
    };
    // FORMAT inside an IF, CASE or loop is state at runtime: the method keeps
    // the color in lv_color, and every write( ) passes it
    let depth = 0;
    for (const s of stmts) {
      const k = kind(s);
      if (CLOSERS.has(k)) depth--;
      if (k === "Format" && depth > 0 && child(s, "Color")) b.runtimeColor = true;
      if (OPENERS.has(k)) depth++;
    }
    if (b.runtimeColor) {
      b.colorVar = this.identifiers.has("lv_color") ? "lv_r2c_color" : "lv_color";
      this.addPrelude(ctx.method, `DATA ${b.colorVar} TYPE string.`);
    }
    this.currentForm = ctx.form;
    this.currentLocals = new Set(stmts.filter((s) => ["Data", "DataBegin", "Constant", "Type", "Ranges", "FieldSymbol"].includes(kind(s)))
      .map((s) => lc(declName(s) ?? "")));
    if (ctx.form) for (const p of ctx.form.params) this.currentLocals.add(p.name);

    for (let i = 0; i < stmts.length; i++) {
      const s = stmts[i];
      // a blank line of the source between two statements stays one
      const first = s.getFirstToken().getRow();
      if (b.lastRow !== undefined && first > b.lastRow + 1 && b.out.length && b.out[b.out.length - 1] !== "") b.out.push("");
      const k = kind(s);
      if (k === "Comment") {
        const text = s.getFirstToken().getStr();
        if (b.lastRow === first && b.out.length && typeof b.out[b.out.length - 1] === "string" && b.out[b.out.length - 1] !== "") {
          b.out[b.out.length - 1] += `  ${text}`;
        } else {
          b.out.push(text.startsWith("*") ? `"${text.slice(1)}` : text);
        }
        b.lastRow = s.getLastToken().getRow();
        continue;
      }
      // EXEC SQL ... ENDEXEC is refused as a whole
      if (k === "ExecSQL") {
        this.refuse(s, REFUSED.ExecSQL);
        while (stmts[i + 1] && kind(stmts[i]) !== "EndExec") i++;
        b.lastRow = stmts[i].getLastToken().getRow();
        continue;
      }
      // a chain of WRITEs is one call chain of the list
      if (k === "Write" && !findTo(s)) {
        const group = [s];
        while (s.getColon() && stmts[i + 1] && kind(stmts[i + 1]) === "Write" && sameColon(stmts[i + 1], s) && !findTo(stmts[i + 1])) {
          group.push(stmts[++i]);
        }
        this.writeChain(group, b);
        b.lastRow = group[group.length - 1].getLastToken().getRow();
        continue;
      }
      // CLEAR: a, b. / DATA: a TYPE i, b TYPE string. stay one chain
      if (s.getColon() && CHAINABLE.has(k) && !this.alvPlan.has(s)) {
        const group = [s];
        while (stmts[i + 1] && kind(stmts[i + 1]) === k && sameColon(stmts[i + 1], s) && !this.alvPlan.has(stmts[i + 1])) group.push(stmts[++i]);
        if (group.length > 1 && !group.some((x) => this.headerLineTouches(x))) {
          const text = this.renderChainGroup(group, b);
          if (text) b.out.push(text);
          b.lastRow = group[group.length - 1].getLastToken().getRow();
          continue;
        }
        i -= group.length - 1;
      }
      const refused = this.refusals.length;
      this.statement(s, b);
      // a refused statement leaves a mark in the draft (--partial)
      if (this.refusals.length > refused) b.out.push(`" report2cloud refused (line ${first}): ${shortText(s).replace(/"/g, "'")}`);
      b.lastRow = s.getLastToken().getRow();
    }
    this.currentForm = undefined;
    return b.out.flatMap((o) => (typeof o === "string" ? [o] : renderChain(o)));
  }

  /** one statement of a body */
  statement(s, b) {
    const k = kind(s);
    const out = b.out;
    const plan = this.alvPlan.get(s);
    if (plan) {
      if (plan.action === "skip") return;
      if (plan.action === "drop") {
        if (plan.todo) this.todo(s, plan.todo);
        this.map(s, `dropped - ${plan.reason}`);
        return;
      }
      if (plan.action === "catch") {
        out.push(`CATCH ${plan.names.join(" ")}${this.catchInto(s)}.`);
        return;
      }
      if (plan.action === "alv") {
        const salv = this.salv.get(plan.salv);
        out.push(...this.alvChain(salv.table, salv.tableTok, salv.settings, salv.lineSelection, s));
        this.map(s, `\`alv( ${salv.table} )\`${salv.settings.length ? " with the column settings" : ""}`);
        return;
      }
      if (plan.action === "reuse") {
        const settings = [...plan.settings];
        for (const c of this.fcat.get(plan.fieldcatVar) ?? []) {
          if (!c.name) continue;
          if (c.text) settings.push({ m: "set_column_text", name: c.name, arg: c.text });
          if (c.hidden) settings.push({ m: "set_column_hidden", name: c.name });
        }
        out.push(...this.alvChain(plan.table, plan.tableNode.getFirstToken(), settings, plan.lineSelection, s));
        for (const t of plan.todos ?? []) this.todo(s, t);
        if (plan.lineSelection) this.todo(s, `${plan.fm}: the USER_COMMAND callback is the row click now - its FORM is converted into at_line_selection( )`);
        this.map(s, `\`alv( ${plan.table} )\``);
        return;
      }
    }

    if (REFUSED[k]) {
      this.refuse(s, REFUSED[k]);
      return;
    }
    if (LAYOUT_ONLY[k]) {
      this.note(LAYOUT_ONLY[k]);
      this.map(s, "dropped - layout only");
      return;
    }

    switch (k) {
      case "Write": {      // WRITE ... TO
        const src = child(s, "Source");
        const target = child(s, "Target");
        const ov = this.rewrites(s, b.ctx);
        out.push(`${nodeText(target, ov)} = |{ ${nodeText(src, ov)} }|.`);
        this.todo(s, "WRITE ... TO: converted to a string template - WRITE TO formats dates, times and numbers in the user's format; add DATE = USER / NUMBER = USER where it matters");
        this.map(s, "string template");
        return;
      }
      case "NewLine":
        this.listCall(b, "new_line", []);
        this.map(s, "`list( )->new_line( )`");
        return;
      case "Skip": {
        if (words(s).includes("TO")) {
          this.note("SKIP TO LINE - the list has no line positions");
          this.map(s, "dropped - SKIP TO LINE");
          return;
        }
        const n = child(s, "Source");
        this.listCall(b, "skip", n && nodeText(n) !== "1" ? [{ value: nodeText(n, this.rewrites(s, b.ctx)) }] : []);
        this.map(s, "`list( )->skip( )`");
        return;
      }
      case "Uline":
        if (child(s, "WriteOffsetLength")) this.note("ULINE AT pos(len) - the line spans the list");
        this.listCall(b, "uline", []);
        this.map(s, "`list( )->uline( )`");
        return;
      case "NewPage": {
        const w = words(s);
        if (hasSeq(w, "PRINT", "ON") || hasSeq(w, "PRINT", "OFF")) {
          this.refuse(s, "NEW-PAGE PRINT ON - printing is not supported");
          return;
        }
        if (w.length > 3) this.note("NEW-PAGE options (NO-TITLE, LINE-SIZE, ...) - the page is a heading line of the list");
        this.listCall(b, "new_page", []);
        if (this.topOfPage) out.push("top_of_page( ).");
        this.map(s, "`list( )->new_page( )`");
        return;
      }
      case "Format":
        this.format(s, b);
        return;
      case "Hide":
        this.hide(s, b);
        return;
      case "Message":
        this.message(s, b);
        return;
      case "Perform":
        this.perform(s, b);
        return;
      case "LoopAtScreen": {
        if (!b.ctx.screenEvent || b.screenLoopDepth >= 0) {
          this.refuse(s, "LOOP AT SCREEN outside of AT SELECTION-SCREEN OUTPUT - only the screen of at_selection_screen_output( screen ) can be changed; move the loop there");
          return;
        }
        const t = lc(renderTokens(stmtTokens(s)));
        const m = /into\s+(?:data\s*\(\s*)?([\w/]+)/.exec(t);
        if (/assigning/.test(t)) {
          this.refuse(s, "LOOP AT SCREEN ASSIGNING - field symbols to screen fields are not converted; use LOOP AT SCREEN with MODIFY SCREEN");
          return;
        }
        b.screenWa = m && /data\s*\(/.test(t) ? m[1] : "ls_screen";
        if (m && !/data\s*\(/.test(t)) {
          this.refuse(s, "LOOP AT SCREEN INTO a declared work area of type SCREEN - write LOOP AT SCREEN (or INTO DATA( ))");
          return;
        }
        b.screenLoopDepth = b.loopDepth;
        b.loopDepth++;
        const tab = this.identifiers.has("lt_screen") ? "lt_r2c_screen" : "lt_screen";
        out.push(`DATA(${tab}) = screen->loop_at_screen( ).`, `LOOP AT ${tab} INTO DATA(${b.screenWa}).`);
        this.map(s, "`LOOP AT screen->loop_at_screen( ) INTO DATA(ls_screen)` - screen-* is ls_screen-*, '0'/'1' are abap_false/abap_true");
        return;
      }
      case "ModifyScreen": {
        if (b.screenLoopDepth < 0) {
          this.refuse(s, "MODIFY SCREEN outside of LOOP AT SCREEN");
          return;
        }
        const t = lc(renderTokens(stmtTokens(s)));
        const m = /from\s+([\w/]+)/.exec(t);
        out.push(`screen->modify_screen( ${m ? m[1] : b.screenWa} ).`);
        this.map(s, "`screen->modify_screen( ls_screen )`");
        return;
      }
      case "Loop": case "Do": case "While": case "LoopExtract": case "Provide":
        b.loopDepth++;
        break;
      case "EndLoop": case "EndSelect": case "EndDo": case "EndWhile": case "EndProvide":
        b.loopDepth--;
        if (b.loopDepth === b.screenLoopDepth && k === "EndLoop") {
          b.screenLoopDepth = -1;
          out.push("ENDLOOP.");
          return;
        }
        break;
      case "SetPFStatus":
        this.todo(s, "SET PF-STATUS dropped - the list has no GUI status; offer the functions as buttons of the selection screen or popups");
        this.map(s, "dropped - SET PF-STATUS");
        return;
      case "SetTitlebar":
        this.todo(s, "SET TITLEBAR dropped - call set_title( ) with the text of the title");
        this.map(s, "dropped - SET TITLEBAR");
        return;
      case "Leave": {
        const t = uc(renderTokens(stmtTokens(s)));
        if (/LEAVE\s+LIST-PROCESSING/.test(t)) {
          out.push("leave_to_selection_screen( ).");
          this.map(s, "`leave_to_selection_screen( )`");
          return;
        }
        if (/LEAVE\s+TO\s+LIST-PROCESSING/.test(t)) {
          this.refuse(s, "LEAVE TO LIST-PROCESSING - the list is shown after start_of_selection( ); write the output there");
          return;
        }
        if (/^LEAVE$/.test(t)) break;
        this.refuse(s, `${t} - the app has no screens or transactions to leave; RETURN ends the event block, leave_to_selection_screen( ) goes back`);
        return;
      }
      case "Stop":
        out.push("RETURN.");
        this.todo(s, "STOP became RETURN - END-OF-SELECTION, appended to start_of_selection( ), does not run after it");
        this.map(s, "`RETURN`");
        return;
      case "CallFunction":
        if (this.callFunction(s, b)) return;
        break;
      case "Call": case "CreateObject": case "Move": {
        const t = lc(renderTokens(stmtTokens(s)));
        if (GUI_CONTROL.test(t)) {
          this.refuse(s, "SAP GUI controls (cl_gui_*) need a dynpro container - use alv( ) or an abap2UI5 view");
          return;
        }
        if (/\bcl_gui_frontend_services\b/.test(t)) {
          this.refuse(s, "cl_gui_frontend_services - there is no SAP GUI frontend; use an abap2UI5 file upload or download");
          return;
        }
        break;
      }
      case "Assign": {
        const t = renderTokens(stmtTokens(s));
        if (/\(\s*'\(/.test(t) || /'\([\w/]+\)/.test(t)) {
          this.refuse(s, "ASSIGN of a field of another program ('(PROG)FIELD') - field symbols to screen or foreign program fields are not available in a class or on ABAP Cloud");
          return;
        }
        break;
      }
      case "Select": case "SelectLoop": {
        if (k === "SelectLoop") b.loopDepth++;
        const t = uc(renderTokens(stmtTokens(s)));
        if (!/\bINTO\b|\bAPPENDING\b/.test(t)) {
          this.refuse(s, "SELECT without INTO - the short form reads into the TABLES work area, which classes do not have; add INTO");
          return;
        }
        break;
      }
      case "Tables":
        this.refuse(s, "TABLES inside a FORM or event block");
        return;
      case "Ranges": {
        const name = lc(declName(s));
        const forText = lc(nodeText(child(s, "SimpleFieldChain2")));
        const root = forText.split("-")[0];
        const like = this.currentLocals.has(root) || (this.globalData.has(root) && (!this.isTables(root) || this.tablesKept.has(root)));
        out.push(`DATA ${name} ${like ? "LIKE" : "TYPE"} RANGE OF ${forText}.`);
        this.map(s, "`DATA ... RANGE OF`");
        return;
      }
      case "Data": {
        const name = lc(declName(s) ?? "");
        if (this.salvVars.has(name) || this.fcatVars.has(name) || this.layoutVars.has(name)) {
          this.map(s, "dropped - the ALV object, field catalog or layout is the alv( ) chain now");
          return;
        }
        const t = uc(renderTokens(stmtTokens(s)));
        if (/\bOCCURS\b|WITH\s+HEADER\s+LINE/.test(t)) {
          this.refuse(s, "a table with a header line (OCCURS / WITH HEADER LINE) - not allowed in classes; declare the table and a work area of its own");
          return;
        }
        if (GUI_CONTROL.test(lc(t))) {
          this.refuse(s, "SAP GUI controls (cl_gui_*) need a dynpro container - use alv( ) or an abap2UI5 view");
          return;
        }
        const ov = this.rewrites(s, b.ctx);
        this.likeToType(s, ov);
        out.push(`${renderTokens(stmtTokens(s), ov, s.getColon()).replace(/^(\w+)(\s*):\s*/, "$1 ")}.`);
        return;
      }
      default:
        break;
    }

    // the screen loop: assignments to unsupported SCREEN fields are dropped
    if (b.screenLoopDepth >= 0) {
      const t = lc(renderTokens(stmtTokens(s)));
      const m = /\bscreen\s*-\s*(\w+)/g;
      let hit;
      while ((hit = m.exec(t))) {
        if (!SCREEN_FIELDS.has(hit[1])) {
          if (k === "Move" && t.startsWith("screen")) {
            this.todo(s, `SCREEN-${uc(hit[1])} has no counterpart (only name, group1, active, input, required, invisible) - the assignment is dropped`);
            this.map(s, "dropped - SCREEN field without a counterpart");
            return;
          }
          this.refuse(s, `SCREEN-${uc(hit[1])} has no counterpart - loop_at_screen( ) has name, group1, active, input, required and invisible`);
          return;
        }
      }
    }

    // the header line of a select-option or RANGES table
    if (this.headerLine(s, b)) return;

    // copied as it is written, with its tokens rewritten
    const ov = this.rewrites(s, b.ctx, b);
    const text = renderTokens(stmtTokens(s), ov, s.getColon()).replace(/^([\w-]+)(\s*):\s*/, "$1 ");
    out.push(`${text}.`);
  }

  /** a statement that names a select-option or RANGES table alone - its
   *  header line is written by headerLine( ) */
  headerLineTouches(s) {
    const names = stmtTokens(s).map((t) => lc(t.getStr()));
    return names.some((n, i) => this.headerTables.has(n) && !this.currentLocals.has(n) && names[i + 1] !== "-"
      && (i === 0 || !["-", "->", "=>", "~"].includes(names[i - 1])));
  }

  /** a chained statement of a body, kept chained */
  renderChainGroup(all, b) {
    const colon = all[0].getColon();
    const group = all.filter((s) => {
      const name = lc(declName(s) ?? "");
      const alv = kind(s) === "Data" && (this.salvVars.has(name) || this.fcatVars.has(name) || this.layoutVars.has(name));
      if (alv) this.map(s, "dropped - the ALV object, field catalog or layout is the alv( ) chain now");
      return !alv;
    });
    if (!group.length) return undefined;
    const prefix = renderTokens(stmtTokens(group[0]).filter((t) => t.getRow() < colon.getRow() || (t.getRow() === colon.getRow() && t.getCol() < colon.getCol())));
    if (["Clear", "Free", "Refresh"].includes(kind(group[0]))) {
      const parts = group.map((s) => renderTokens(partTokens(s), this.rewrites(s, b.ctx, b)));
      const line = `${prefix}: ${parts.join(", ")}.`;
      if (line.length <= 120) return line;
    }
    const lines = [`${prefix}:`];
    let depth = 1;
    group.forEach((s, idx) => {
      const k = kind(s);
      if (/End$/.test(k)) depth--;
      const ov = this.rewrites(s, b.ctx, b);
      this.likeToType(s, ov);
      const pad = "  ".repeat(depth);
      lines.push(`${pad}${renderTokens(partTokens(s), ov).replace(/\n/g, `\n${pad}`)}${idx === group.length - 1 ? "." : ","}`);
      if (/Begin$/.test(k)) depth++;
    });
    return lines.join("\n");
  }

  addPrelude(method, line) {
    if (!this.prelude.has(method)) this.prelude.set(method, []);
    if (!this.prelude.get(method).includes(line)) this.prelude.get(method).push(line);
  }

  /** the work area that stands for the header line of a select-option or
   *  RANGES table in a method */
  useWa(method, name) {
    const wa = (this.identifiers.has(`ls_${name}`) ? `ls_r2c_${name}` : `ls_${name}`).slice(0, 30);
    if (!this.methodWa.has(method)) this.methodWa.set(method, new Map());
    this.methodWa.get(method).set(name, wa);
    return wa;
  }

  /** APPEND s. / CLEAR s. / REFRESH s. / LOOP AT s. / READ TABLE s ... of a
   *  table with header line - true when the statement was written here */
  headerLine(s, b) {
    const k = kind(s);
    const toks = stmtTokens(s);
    const names = toks.map((t) => lc(t.getStr()));
    const tab = names.find((n, i) => this.headerTables.has(n) && !this.currentLocals.has(n) && (i === 0 || !["-", "->", "=>", "~"].includes(names[i - 1])));
    if (!tab) return false;
    const ov = this.rewrites(s, b.ctx, b);
    const text = () => renderTokens(toks, ov, s.getColon()).replace(/^([\w-]+)(\s*):\s*/, "$1 ");
    const has = (...w) => w.some((x) => names.includes(x));
    if (k === "Append" && names.length === 2 && names[1] === tab) {
      b.out.push(`APPEND ${this.useWa(b.ctx.method, tab)} TO ${tab}.`);
      this.map(s, `\`APPEND ls_${tab} TO ${tab}\` - the header line is a work area`);
      return true;
    }
    if (k === "Refresh" && names.length === 2 && names[1] === tab) {
      b.out.push(`CLEAR ${tab}.`);
      return true;
    }
    if (k === "Clear" && names.length === 2 && names[1] === tab) {
      b.out.push(`CLEAR ${this.useWa(b.ctx.method, tab)}.`);
      this.map(s, `\`CLEAR ls_${tab}\` - the header line is a work area`);
      return true;
    }
    if ((k === "Loop" || k === "ReadTable") && !has("into", "assigning", "reference", "transporting")) {
      const src = child(s, k === "Loop" ? "LoopSource" : "SimpleSource2");
      if (src && lc(nodeText(src)) === tab) {
        const last = src.getLastToken();
        const wa = this.useWa(b.ctx.method, tab);
        if (k === "Loop") ov.set(key(last), `${last.getStr()} INTO ${wa}`);
        b.out.push(k === "Loop" ? `${text()}.` : `${text()} INTO ${wa}.`);
        this.map(s, `\`INTO ls_${tab}\` - the header line is a work area`);
        return true;
      }
    }
    if (["Append", "InsertInternal", "ModifyInternal", "Collect"].includes(k) && names.length === 2) {
      this.refuse(s, `${uc(names[0])} ${tab} - the header line of ${tab} is not converted here; use a work area`);
      return true;
    }
    return false;
  }

  catchInto(s) {
    const t = renderTokens(stmtTokens(s));
    const m = /\bINTO\s+(.+)$/i.exec(t);
    return m ? ` INTO ${m[1]}` : "";
  }

  /**
   * The token rewrites of a statement in its method: text symbols become
   * literals, sy-ucomm the ucomm parameter, screen-* the line of
   * loop_at_screen( ), icons of type pool ICON the UI5 icon.
   */
  rewrites(s, ctx = {}, b = undefined) {
    const ov = new Map();
    for (const te of findAll(s, "TextElement")) {
      const toks = te.getTokens();
      ov.set(key(toks[0]), this.textSymbol(nodeText(child(te, "TextElementKey")), undefined, s));
      for (const t of toks.slice(1)) ov.set(key(t), null);
    }
    for (const te of findAll(s, "TextElementString")) {
      const toks = te.getTokens();
      const keyText = nodeText(child(te, "TextElementKey"));
      ov.set(key(toks[0]), this.textSymbol(keyText, unquote(toks[0].getStr()), s));
      for (const t of toks.slice(1)) ov.set(key(t), null);
    }
    const toks = stmtTokens(s);
    for (let i = 0; i < toks.length; i++) {
      const t = lc(toks[i].getStr());
      const prev = i > 0 ? toks[i - 1].getStr() : "";
      const component = prev === "-" || prev === "->" || prev === "=>" || prev === "~";
      if (component) continue;
      const next = toks[i + 1]?.getStr();
      const next2 = lc(toks[i + 2]?.getStr() ?? "");
      if ((ctx.userCommand || ctx.ucomm) && (t === "sy" || t === "sscrfields") && next === "-" && next2 === "ucomm") {
        if (t === "sy" || ctx.ucomm) {
          ov.set(key(toks[i]), "ucomm");
          ov.set(key(toks[i + 1]), null);
          ov.set(key(toks[i + 2]), null);
        }
      }
      if (t === "sy" && next === "-" && next2 === "ucomm" && !(ctx.userCommand || ctx.ucomm) && !this.ucommTodo?.has(s)) {
        this.ucommTodo = new Set([...(this.ucommTodo ?? []), s]);
        this.todo(s, "sy-ucomm is not set by abap-cloud-gui - the user command arrives as ucomm in at_user_command( ); pass it to where it is read");
      }
      if (ctx.lineSelection && t === "sy" && next === "-" && ["lilli", "curow"].includes(next2)) {
        ov.set(key(toks[i]), "row");
        ov.set(key(toks[i + 1]), null);
        ov.set(key(toks[i + 2]), null);
      }
      if (ctx.lineSelection && t === "sy" && next === "-" && next2 === "lisel") {
        this.todo(s, "sy-lisel (the text of the clicked line) is not set - read the data of the line through HIDE or row instead");
      }
      if (b && this.headerTables.has(t) && !this.currentLocals.has(t)) {
        if (next === "-") ov.set(key(toks[i]), this.useWa(b.ctx.method, t));
        if (next === "[" && toks[i + 2]?.getStr() === "]") {
          ov.set(key(toks[i + 1]), null);
          ov.set(key(toks[i + 2]), null);
        }
      }
      if (b && b.screenLoopDepth >= 0 && t === "screen" && next === "-") {
        ov.set(key(toks[i]), b.screenWa);
        const field = next2;
        // screen-active = '0' / 1 -> abap_false / abap_true
        const op = toks[i + 3];
        const val = toks[i + 4];
        if (SCREEN_FLAGS.has(field) && op && ["=", "EQ", "<>", "NE"].includes(uc(op.getStr())) && val) {
          const v = val.getStr().replace(/['`]/g, "");
          if (v === "0" || v === "1") ov.set(key(val), v === "1" ? "abap_true" : "abap_false");
          else if (!/^abap_/i.test(v)) this.todo(s, `SCREEN-${uc(field)} is an abap_bool here, not '0' / '1' - check the value ${val.getStr()}`);
        }
        if (field === "name" && op && val && /^'[\w/]+-(LOW|HIGH)'$/i.test(val.getStr())) {
          ov.set(key(val), `'${uc(val.getStr().slice(1, -1).replace(/-(LOW|HIGH)$/i, ""))}'`);
        }
      }
      if (ICONS[t] && !this.globalData.has(t) && !this.currentLocals?.has(t)) {
        ov.set(key(toks[i]), literal(ICONS[t]));
      }
    }
    this.strictSql(s, ov);
    return ov;
  }

  /** ABAP SQL in strict mode, as ABAP Cloud demands it: host variables
   *  escaped with @, the field list separated by commas. Syntax only - the
   *  parser tells a host variable (SQLSource, SQLTarget) from a column. A
   *  statement that escapes already is left as it is. */
  strictSql(s, ov) {
    if (!["Select", "SelectLoop", "UpdateDatabase", "ModifyDatabase", "InsertDatabase", "DeleteDatabase", "OpenCursor"].includes(kind(s))) return;
    if (s.getTokens().some((t) => t.getStr().startsWith("@"))) return;
    const escape = (tok) => {
      const k = key(tok);
      ov.set(k, `@${ov.has(k) ? ov.get(k) : tok.getStr()}`);
    };
    let changed = false;
    for (const k of ["SQLSource", "SQLSourceSimple"]) {
      for (const src of findAll(s, k)) {
        const first = src.getChildren()[0];
        if (!first || isToken(first)) continue;
        const inner = first.getChildren()[0];
        if ((kind(first) === "Source" || kind(first) === "SimpleSource3") && inner && !isToken(inner) && kind(inner) === "FieldChain") {
          escape(src.getFirstToken());
          changed = true;
        }
      }
    }
    for (const t of findAll(s, "SQLTarget")) {
      escape(t.getFirstToken());
      changed = true;
    }
    if (!changed) return;
    for (const list of findAll(s, "SQLFieldList")) {
      const fields = children(list, "SQLField");
      if (fields.length < 2 || list.getTokens().some((t) => t.getStr() === ",")) continue;
      for (const f of fields.slice(0, -1)) {
        const last = f.getLastToken();
        const k = key(last);
        ov.set(k, `${ov.has(k) ? ov.get(k) : last.getStr()},`);
      }
    }
  }

  // ----------------------------------------------------------------- list

  listCall(b, method, params) {
    const item = { method, params, positional: true };
    b.out.push({ items: [item] });
    if (method !== "write") b.line = [];
  }

  format(s, b) {
    const w = words(s);
    const color = child(s, "Color");
    if (w.includes("RESET")) {
      b.color = "none";
      b.hotspot = false;
      if (b.runtimeColor) b.out.push(`CLEAR ${b.colorVar}.`);
    }
    if (color) {
      const c = color.getTokens().map((t) => uc(t.getStr()));
      if (c[1] === "=") {
        this.todo(s, "FORMAT COLOR = variable - a dynamic color is not mapped, the list writes without color");
        b.color = "none";
      } else {
        b.color = COLORS[c[1]] ?? "none";
      }
      if (b.runtimeColor) b.out.push(b.color === "none" ? `CLEAR ${b.colorVar}.` : `${b.colorVar} = ${colorConst(b.color)}.`);
    }
    const hs = w.indexOf("HOTSPOT");
    if (hs >= 0) b.hotspot = w[hs + 1] !== "OFF";
    if (w.includes("INTENSIFIED") || w.includes("INVERSE") || w.includes("INPUT") || w.includes("FRAMES")) {
      this.note("FORMAT INTENSIFIED / INVERSE / INPUT - the list knows only the color and hotspots");
    }
    this.map(s, b.runtimeColor ? "`lv_color`, passed to every `write( )` of the method" : "applied to the following `write( )` calls of the method (color, hotspot)");
  }

  /** WRITE: / a, b COLOR 5 HOTSPOT ... - one chain of the list */
  writeChain(group, b) {
    const items = [];
    for (const s of group) {
      const w = words(s);
      const ov = this.rewrites(s, b.ctx, b);
      const offs = child(s, "WriteOffsetLength");
      const slash = w.includes("/") || (offs && offs.getTokens().some((t) => t.getStr().startsWith("/")));
      if (slash) {
        items.push({ method: "new_line", params: [] });
        b.line = [];
      }
      if (offs && offs.getTokens().some((t) => !t.getStr().startsWith("/") && t.getStr() !== "AT")) {
        this.note("WRITE at a position or with a length - the list writes item after item");
      }
      const src = child(s, "Source");
      if (!src) continue;
      const value = nodeText(src, ov);
      if (hasSeq(w, "AS", "CHECKBOX")) {
        items.push({ method: "write_as_checkbox", params: [{ value }] });
        this.map(s, "`list( )->write_as_checkbox( )`");
        continue;
      }
      if (hasSeq(w, "AS", "ICON")) {
        items.push({ method: "write_as_icon", params: [{ value }] });
        if (!/^`sap-icon:/.test(value)) this.todo(s, `WRITE ${value} AS ICON - write_as_icon( ) takes a UI5 icon (sap-icon://...), not an icon of type pool ICON; map the value`);
        this.map(s, "`list( )->write_as_icon( )`");
        continue;
      }
      const color = child(s, "Color");
      let c = b.color;
      if (color) {
        const ct = color.getTokens().map((t) => uc(t.getStr()));
        if (ct[1] === "=") {
          this.todo(s, "WRITE ... COLOR = variable - a dynamic color is not mapped");
          c = "none";
        } else c = COLORS[ct[1]] ?? "none";
      }
      let hotspot = b.hotspot;
      const hs = w.indexOf("HOTSPOT");
      if (hs >= 0) hotspot = w[hs + 1] !== "OFF";
      const lost = ["NO-GAP", "UNDER", "CURRENCY", "UNIT", "DECIMALS", "EDIT", "LEFT-JUSTIFIED", "CENTERED",
        "RIGHT-JUSTIFIED", "NO-ZERO", "NO-SIGN", "EXPONENT", "ROUND", "DD/MM/YY", "MM/DD/YY", "DD/MM/YYYY",
        "MM/DD/YYYY", "DDMMYY", "MMDDYY", "YYMMDD", "QUICKINFO", "INPUT", "INVERSE", "TIME", "ENVIRONMENT"];
      const joined = w.join(" ").replace(/ - /g, "-");
      for (const o of lost) {
        if (new RegExp(`(^| )${o.replace(/\//g, "\\/")}( |$)`).test(joined)) this.note(`WRITE ... ${o} - the list writes the value in its default format`);
      }
      const item = { method: "write", params: [{ name: "val", value }] };
      if (color || !b.runtimeColor) {
        if (c !== "none") item.params.push({ name: "color", value: colorConst(c) });
      } else {
        item.params.push({ name: "color", value: b.colorVar });
      }
      if (hotspot) item.params.push({ name: "hotspot", value: "abap_true" });
      items.push(item);
      b.line.push(item);
      this.map(s, `\`write( )\`${c !== "none" ? ", color" : ""}${hotspot ? ", hotspot" : ""}`);
    }
    if (items.length) b.out.push({ items });
  }

  hide(s, b) {
    const src = child(s, "Source");
    const name = lc(nodeText(src));
    const root = name.split("-")[0];
    if (!this.globalData.has(root)) {
      this.refuse(s, `HIDE ${name} - the field is not a global field of the report, so at_line_selection( ) cannot restore it`);
      return;
    }
    let target = b.line.find((it) => it.params.some((p) => p.name === "hotspot")) ?? b.line[0];
    if (!target) {
      this.refuse(s, "HIDE without a WRITE before it in the same block - the hidden value is attached to the hotspot of the line it follows");
      return;
    }
    if (!target.params.some((p) => p.name === "hotspot")) target.params.push({ name: "hotspot", value: "abap_true" });
    target.hide = [...(target.hide ?? []), name];
    const set = target.hide.join(",");
    if (this.hideSet && !this.hideSet.startsWith(set) && !set.startsWith(this.hideSet)) {
      this.refuse(s, `HIDE of other fields (${target.hide.join(", ")}) than elsewhere (${this.hideSet}) - one set of hidden fields per report is supported`);
      return;
    }
    if (!this.hideSet || set.length > this.hideSet.length) this.hideSet = set;
    // the value of the hotspot: the field, or all fields of the line joined
    const hide = target.hide.length === 1 ? target.hide[0] : `|${target.hide.map((f) => `{ ${f} }`).join("\\t")}|`;
    target.params = target.params.filter((p) => p.name !== "hide");
    target.params.push({ name: "hide", value: hide });
    this.map(s, `\`hide = ${target.hide.join(" ")}\` at the hotspot of the line, restored in \`at_line_selection( )\``);
  }

  hideRestore() {
    if (!this.hideSet) return [];
    const fields = this.hideSet.split(",");
    if (fields.length === 1) return ["\" HIDE - the field the clicked line was written with", `${fields[0]} = hide.`];
    const lines = ["\" HIDE - the fields the clicked line was written with", "SPLIT hide AT |\\t| INTO TABLE DATA(lt_hide)."];
    fields.forEach((f, i) => lines.push(`${f} = VALUE #( lt_hide[ ${i + 1} ] OPTIONAL ).`));
    return lines;
  }

  // -------------------------------------------------------------- messages

  message(s, b) {
    const w = words(s);
    const ov = this.rewrites(s, b.ctx, b);
    if (w.includes("INTO")) {
      // MESSAGE ... INTO is no output - copied
      b.out.push(`${renderTokens(stmtTokens(s), ov)}.`);
      return;
    }
    if (w.includes("RAISING")) {
      this.refuse(s, "MESSAGE ... RAISING - classic exceptions of a FORM or function; raise a class-based exception instead");
      return;
    }
    const typeNode = after(s, "TYPE", "Source");
    const like = after(s, "LIKE", "Source");
    const msgSrc = child(s, "MessageSource");
    const textSrc = child(s, "MessageSourceSource");
    let type;
    let text;
    const lines = [];
    if (msgSrc) {
      // a message of a message class - its text comes through MESSAGE ... INTO
      const tn = child(msgSrc, "MessageTypeAndNumber");
      let head;
      if (tn) {
        const tnText = nodeText(tn);
        const cls = child(msgSrc, "MessageClass");
        const msgClass = cls ? nodeText(cls) : this.header?.messageClass;
        if (!msgClass) {
          this.refuse(s, "MESSAGE without a message class - neither in the statement nor MESSAGE-ID of REPORT");
          return;
        }
        head = `MESSAGE ${lc(tnText)}(${lc(msgClass)})`;
        type = literal(uc(tnText[0]));
        this.messageClasses = new Set([...(this.messageClasses ?? []), uc(msgClass)]);
      } else {
        head = `MESSAGE ${renderTokens(msgSrc.getTokens(), ov)}`;
        const tNode = after(msgSrc, "TYPE");
        type = tNode ? nodeText(tNode, ov) : literal("S");
        const id = after(msgSrc, "ID");
        if (id && /^'/.test(nodeText(id))) this.messageClasses = new Set([...(this.messageClasses ?? []), uc(unquote(nodeText(id)))]);
      }
      const withIdx = s.getChildren().findIndex((c) => isToken(c) && uc(c.get().getStr()) === "WITH");
      const withPart = withIdx >= 0 ? ` WITH ${children(s, "MessageSourceSource").map((n) => nodeText(n, ov)).join(" ")}` : "";
      const into = this.msgDeclared.has(b.ctx.method) ? this.msgVar : `DATA(${this.msgVar})`;
      this.msgDeclared.add(b.ctx.method);
      lines.push(`${head}${withPart} INTO ${into}.`);
      text = this.msgVar;
      this.map(s, "`MESSAGE ... INTO` + `message( )`");
    } else {
      text = nodeText(textSrc, ov);
      type = typeNode ? nodeText(typeNode, ov) : literal("S");
      this.map(s, "`message( )`");
    }
    type = /^'(.)'$/.test(type) ? literal(uc(type[1])) : type;
    let displayLike;
    if (like) {
      displayLike = nodeText(like, ov);
      if (/^['`][EW]['`]$/i.test(displayLike) && /^`[SI]`$/.test(type)) {
        type = literal("W");
        this.note("MESSAGE ... DISPLAY LIKE 'E' - a status or info message displayed as an error becomes a warning (shown in the popover, the run goes on)");
      }
    }
    if (type === "`S`") lines.push(`message( ${text} ).`);
    else lines.push(`message( text = ${text}\n         type = ${type} ).`);
    b.out.push(...lines);
    if (type === "`E`" || type === "`A`") {
      b.out.push("RETURN.");
      if (b.ctx.form) this.todo(s, `MESSAGE TYPE ${type[1]} in FORM ${b.ctx.form.name}: the classic message ended the event block, RETURN here only leaves ${b.ctx.form.method}( ) - the runtime still stops the run, but the caller continues`);
    }
    if (type === "`X`") this.todo(s, "MESSAGE TYPE X - a dump; message( ) shows it as an abort message instead");
  }

  // -------------------------------------------------------------- PERFORM

  perform(s, b) {
    const w = words(s);
    const nameNode = child(s, "FormName");
    if (!nameNode || w.includes("IN") || child(s, "IncludeName") || hasSeq(w, "IF", "FOUND") || w.includes("ON")) {
      this.refuse(s, "PERFORM of a FORM of another program, dynamic or ON COMMIT - only FORMs of this report are converted");
      return;
    }
    const name = lc(nodeText(nameNode));
    const f = this.formByName.get(name);
    if (!f) {
      this.refuse(s, `PERFORM ${name} - no FORM ${name} in this report`);
      return;
    }
    if (this.alvCallbacks.has(name)) {
      this.refuse(s, `PERFORM ${name} - the FORM is a callback of the ALV and is not converted to a method`);
      return;
    }
    if (this.emptyForms.has(name)) {
      this.map(s, `dropped - FORM ${name} only set up the ALV`);
      return;
    }
    f.performed = true;
    const ov = this.rewrites(s, b.ctx, b);
    const tables = child(s, "PerformTables") ? children(child(s, "PerformTables")) : [];
    const using = child(s, "PerformUsing") ? children(child(s, "PerformUsing")) : [];
    const changing = child(s, "PerformChanging") ? children(child(s, "PerformChanging")) : [];
    const formTables = f.params.filter((p) => p.kind === "tables");
    const formOther = f.params.filter((p) => p.kind !== "tables");
    const actualOther = [...using, ...changing];
    if (tables.length !== formTables.length || actualOther.length !== formOther.length) {
      this.refuse(s, `PERFORM ${name} passes ${tables.length + actualOther.length} parameters, FORM ${name} has ${f.params.length}`);
      return;
    }
    const imp = [];
    const chg = [];
    const pairs = [...formTables.map((p, i) => [p, tables[i]]), ...formOther.map((p, i) => [p, actualOther[i]])];
    for (const [p, node] of pairs) {
      const value = nodeText(node, ov);
      const isVar = /^[\w/<>~-]+$/.test(value) && !/^\d+$/.test(value) && !findAll(node, "Constant").length;
      const changingParam = p.kind !== "using" || p.promoted;
      if (changingParam && !isVar) {
        this.refuse(s, `PERFORM ${name}: ${value} is passed to ${p.name}, which the FORM changes - a CHANGING parameter of the method needs a variable`);
        return;
      }
      (changingParam ? chg : imp).push({ name: p.name, value });
    }
    const call = renderCall(f.method, imp, chg);
    b.out.push(call);
    this.map(s, `\`${f.method}( )\``);
  }

  // ------------------------------------------------------------- functions

  callFunction(s, b) {
    const fm = uc(unquote(nodeText(child(s, "FunctionName")).trim()));
    if (REFUSED_FUNCTIONS[fm]) {
      this.refuse(s, `CALL FUNCTION '${fm}' - ${REFUSED_FUNCTIONS[fm]}`);
      return true;
    }
    if (/^REUSE_ALV_/.test(fm) || /^LVC_/.test(fm)) {
      this.refuse(s, `CALL FUNCTION '${fm}' - only REUSE_ALV_GRID_DISPLAY / REUSE_ALV_LIST_DISPLAY with TABLES t_outtab are converted`);
      return true;
    }
    if (fm === "F4IF_INT_TABLE_VALUE_REQUEST") {
      if (!b.ctx.valueRequest) {
        this.refuse(s, "F4IF_INT_TABLE_VALUE_REQUEST outside of AT SELECTION-SCREEN ON VALUE-REQUEST - only an F4 of the selection screen is converted");
        return true;
      }
      const p = functionParams(s);
      const tab = p.get("value_tab");
      const ret = p.get("retfield");
      if (!tab) {
        this.refuse(s, "F4IF_INT_TABLE_VALUE_REQUEST without TABLES value_tab - not understood");
        return true;
      }
      const ov = this.rewrites(s, b.ctx, b);
      const col = ret ? nodeText(ret.node, ov) : undefined;
      const colValue = col && /^'[^']*'$/.test(col) ? literal(uc(unquote(col))) : col;
      const params = [{ name: "tab", value: nodeText(tab.node, ov) }];
      if (colValue) params.push({ name: "col", value: colValue });
      const title = p.get("window_title");
      if (title) params.push({ name: "title", value: nodeText(title.node, ov) });
      b.out.push(renderNamedCall("value_help_popup", params));
      if (p.has("return_tab")) this.todo(s, "F4IF_INT_TABLE_VALUE_REQUEST: value_help_popup( ) writes the picked value into the field itself - the handling of RETURN_TAB after it has nothing to read any more");
      this.map(s, "`value_help_popup( )` - the picked value is written into the field");
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------------ ALV

  alvChain(table, tableTok, settings, lineSelection, s) {
    const root = lc(table.split("-")[0]);
    if (!this.globalData.has(root)) {
      this.todo(s, `alv( ${table} ): the table is no attribute of the class - alv( ) copies it into a data reference, which the draft rebuilds with RTTI on every roundtrip; make it a global DATA of the report`);
    }
    // the last text of a column wins - long over medium over short
    const rank = { set_short_text: 1, set_medium_text: 2, set_long_text: 3 };
    const texts = new Map();
    const hidden = [];
    let title;
    for (const st of settings) {
      if (st.m === "set_title") title = st.arg;
      if (st.m === "set_column_text") {
        const prev = texts.get(st.name);
        if (!prev || (rank[st.rank] ?? 3) >= (rank[prev.rank] ?? 3)) texts.set(st.name, st);
      }
      if (st.m === "set_column_hidden" && !hidden.includes(st.name)) hidden.push(st.name);
    }
    const items = [{ method: "alv", params: [{ value: lc(table) }] }];
    if (title) items.push({ method: "set_title", params: [{ value: this.literalArg(title, s) }] });
    for (const [name, st] of texts) {
      items.push({ method: "set_column_text", params: [{ name: "name", value: literal(name) }, { name: "text", value: this.literalArg(st.arg, s) }] });
    }
    for (const name of hidden) items.push({ method: "set_column_hidden", params: [{ value: literal(name) }] });
    if (lineSelection) items.push({ method: "set_line_selection", params: [] });
    return renderChain({ items, head: "" });
  }

  /** an argument written in the report - a TEXT-001 becomes its text */
  literalArg(arg, s) {
    const m = /^text-(\w+)$/i.exec(arg.trim());
    if (m) return this.textSymbol(m[1], undefined, s);
    const m2 = /^('(?:[^']|'')*')\((\w+)\)$/.exec(arg.trim());
    if (m2) return this.textSymbol(m2[2], unquote(m2[1]), s);
    return arg.trim();
  }

  /** the USER_COMMAND callback of REUSE_ALV_GRID_DISPLAY as the body of
   *  at_line_selection( ): the ucomm is the double click, the selfield's
   *  tabindex the row */
  alvCallbackBody(f) {
    const [ucomm, selfield] = f.params.map((p) => p.name);
    if (f.params.length !== 2) {
      this.refuse(f.stmt, `FORM ${f.name} is the USER_COMMAND callback of the ALV and needs two parameters (r_ucomm, rs_selfield)`);
      return [];
    }
    this.map(f.stmt, "the ALV USER_COMMAND callback - its body is `at_line_selection( )`, rs_selfield-tabindex is row");
    const body = this.convertBody(f.body, { method: "at_line_selection", lineSelection: true, callback: { ucomm, selfield } });
    const lines = [`" the ALV double click - FORM ${f.name}, the USER_COMMAND callback`];
    if (new RegExp(`\\b${ucomm}\\b`, "i").test(body.join("\n"))) lines.push(`DATA(${ucomm}) = \`&IC1\`.`);
    // rs_selfield-tabindex -> row
    for (const l of body) {
      const re = new RegExp(`\\b${selfield}\\s*-\\s*(\\w+)`, "gi");
      let bad;
      const out = l.replace(re, (all, comp) => {
        if (lc(comp) === "tabindex") return "row";
        bad = comp;
        return all;
      });
      if (bad) {
        this.refuse(f.stmt, `FORM ${f.name}: ${selfield}-${bad} has no counterpart - at_line_selection( ) has the row only`);
      }
      lines.push(out);
    }
    return lines;
  }

  // --------------------------------------------------------------- locals

  localsSource() {
    if (!this.locals.length) return {};
    const globals = new Set([...this.globalData, ...this.globalTypes]);
    const usedInDecl = [...this.decls, ...this.forms.map((f) => f.stmt)].some((s) => s.getTokens().some((t) => this.localNames.has(lc(t.getStr()))));
    const def = [];
    const imp = [];
    for (const u of this.locals) {
      const declared = new Set();
      for (const s of u.stmts) {
        if (["Data", "ClassData", "Constant", "Type", "MethodDef", "FieldSymbol"].includes(kind(s))) declared.add(lc(declName(s) ?? ""));
        for (const p of findAll(s, "MethodParamName")) declared.add(lc(nodeText(p)));
        for (const p of findAll(s, "InlineData")) declared.add(lc(p.getTokens()[2]?.getStr() ?? ""));
      }
      for (const s of u.stmts) {
        const k = kind(s);
        if (["Perform", "Write", "Uline", "Skip", "NewLine", "Format", "Hide"].includes(k)) {
          this.refuse(s, `${uc(renderTokens(stmtTokens(s)).split(/\s/)[0])} in a local class - the class has no list and no FORMs of the report; move the statement into the report's methods`);
          continue;
        }
        const toks = stmtTokens(s);
        for (let i = 0; i < toks.length; i++) {
          const t = lc(toks[i].getStr());
          const prev = i > 0 ? toks[i - 1].getStr() : "";
          if (["-", "->", "=>", "~"].includes(prev)) continue;
          if (globals.has(t) && !declared.has(t)) {
            this.refuse(toks[i], `the local class uses ${t}, a global of the report - a local class of the generated class cannot reach the report's attributes; pass it as a parameter`);
            break;
          }
        }
      }
      const first = u.stmts[0].getFirstToken().getRow();
      const last = u.stmts[u.stmts.length - 1].getLastToken().getRow();
      const text = this.lines.slice(first - 1, last).join("\n");
      if (usedInDecl && ["ClassDefinition", "Interface", "ClassDeferred", "InterfaceDeferred"].includes(u.kind)) def.push(text);
      else imp.push(text);
      this.mapped.push({ row: first, col: 1, classic: renderTokens(stmtTokens(u.stmts[0])).split("\n")[0], target: usedInDecl && u.kind !== "ClassImplementation" ? "locals_def" : "locals_imp" });
    }
    return { def: def.join("\n\n"), imp: imp.join("\n\n") };
  }

  fieldSymbolDecls(body) {
    if (!this.globalFieldSymbols) return [];
    const text = body.join("\n").toLowerCase();
    return this.globalFieldSymbols
      .filter((s) => text.includes(lc(declName(s))))
      .map((s) => `${renderTokens(stmtTokens(s), new Map(), s.getColon()).replace(/^([\w-]+)(\s*):\s*/, "$1 ")}.`);
  }

  // --------------------------------------------------------- the class text

  /** indent the class as the house style does - two blanks per level, the
   *  lines of a statement kept relative to its first line */
  reindent(text, filename) {
    const reg = new abaplint.Registry();
    reg.addFile(new abaplint.MemoryFile(filename, text));
    reg.parse();
    const file = reg.getFirstObject().getABAPFiles()[0];
    const statements = file.getStatements();
    const expected = new Indent({}).getExpectedIndents(file);
    const lines = text.split("\n");
    const done = new Set();
    for (let i = 0; i < statements.length; i++) {
      const s = statements[i];
      const exp = expected[i];
      const row = (s.getColon() ? s.getColon() : s.getFirstToken()).getRow() - 1;
      if (exp === undefined || exp < 0 || done.has(row)) continue;
      const last = s.getLastToken().getRow() - 1;
      const current = lines[row].length - lines[row].trimStart().length;
      const delta = exp - 1 - current;
      if (s.getColon()) {
        // a chained statement: its parts move with the chain's first line
        let end = i;
        while (statements[end + 1] && statements[end + 1].getColon() === s.getColon()) end++;
        const lastRow = statements[end].getLastToken().getRow() - 1;
        for (let r = row; r <= lastRow; r++) if (!done.has(r)) { lines[r] = shift(lines[r], delta); done.add(r); }
        i = end;
        continue;
      }
      for (let r = row; r <= last; r++) {
        if (done.has(r)) continue;
        lines[r] = shift(lines[r], delta);
        done.add(r);
      }
    }
    return lines.join("\n");
  }

  // -------------------------------------------------------- release TODOs

  /** the objects the generated class uses that ABAP Cloud may not release -
   *  database tables, DDIC types, function modules, classes, message classes */
  releaseTodos(files) {
    const name = `${this.className}.clas.abap`;
    const reg = new abaplint.Registry();
    for (const [f, text] of Object.entries(files)) if (f.endsWith(".abap")) reg.addFile(new abaplint.MemoryFile(f, text));
    reg.parse();
    const found = new Map();
    const add = (objKind, objName, tok, file) => {
      const n = lc(objName);
      if (!n || /^z2ui5_/.test(n) || this.localNames.has(n)) return;
      // one entry per name - a table that also types a field is a table
      const prev = found.get(n);
      if (!prev || (prev.kind === "DDIC type" && objKind === "database table")) {
        found.set(n, { kind: objKind, name: uc(n), file, row: prev?.row ?? tok.getRow(), col: prev?.col ?? tok.getCol(), successor: SUCCESSORS[n] });
      }
    };
    const localTypes = new Set([...this.globalTypes, ...this.tablesTypes.keys()]);
    const files0 = [...reg.getObjects()].flatMap((o) => o.getABAPFiles());
    for (const file of files0) {
      for (const s of file.getStatements()) {
        if (["Type", "TypeBegin", "TypeEnum", "TypeEnumBegin"].includes(kind(s))) localTypes.add(lc(declName(s) ?? ""));
        if (["ClassDefinition", "Interface"].includes(kind(s))) localTypes.add(lc(nodeText(child(s, "ClassName") ?? child(s, "InterfaceName") ?? s.getChildren()[1])));
      }
    }
    for (const file of files0) {
      const fname = file.getFilename();
      for (const s of file.getStatements()) {
        const k = kind(s);
        for (const db of findAll(s, "DatabaseTable")) add("database table", nodeText(db), db.getFirstToken(), fname);
        if (k === "CallFunction") {
          const fn = child(s, "FunctionName");
          add("function module", unquote(nodeText(fn).trim()), fn.getFirstToken(), fname);
        }
        for (const t of findAll(s, "TypeName")) {
          const toks = t.getTokens();
          const n = lc(toks[0].getStr());
          if (BUILTIN_TYPES.has(n) || localTypes.has(n) || toks.some((x) => x.getStr() === "=>")) continue;
          add("DDIC type", n, t.getFirstToken(), fname);
        }
        for (const c of findAll(s, "ClassName")) {
          const n = lc(nodeText(c));
          if (/^(cx_root|cx_static_check|cx_dynamic_check|cx_no_check|cx_sy_\w+|me|super)$/.test(n) || localTypes.has(n)) continue;
          add("class", n, c.getFirstToken(), fname);
        }
      }
    }
    for (const m of this.messageClasses ?? []) {
      found.set(`message class ${m}`, { kind: "message class", name: m, file: name, row: 0, col: 0, successor: undefined });
    }
    return [...found.values()].sort((a, b) => a.kind.localeCompare(b.kind) || a.name.localeCompare(b.name));
  }
}

// ------------------------------------------------------------------ helpers

function shortText(s) {
  const t = renderTokens(stmtTokens(s), new Map(), s.getColon()).replace(/\s+/g, " ");
  return t.length > 60 ? `${t.slice(0, 57)}...` : t;
}

function shift(line, delta) {
  if (!line.trim()) return line;
  if (delta >= 0) return " ".repeat(delta) + line;
  const lead = line.length - line.trimStart().length;
  return line.slice(Math.min(-delta, lead));
}

/** DATA a TYPE i. / DATA bb TYPE string. - the names of a run padded */
function alignData(list) {
  let i = 0;
  while (i < list.length) {
    let j = i;
    while (j < list.length && /^DATA \S+ [^\n]*\.$/.test(list[j]) && !list[j].includes("\n")) j++;
    if (j - i > 1) {
      const width = Math.max(...list.slice(i, j).map((l) => l.split(" ")[1].length));
      for (let r = i; r < j; r++) {
        const [, name, ...rest] = list[r].split(" ");
        list[r] = `DATA ${name.padEnd(width)} ${rest.join(" ")}`;
      }
    }
    i = Math.max(j, i + 1);
  }
}

function indent(text, n) {
  if (!text) return "";
  const pad = " ".repeat(n);
  return pad + text.replace(/\n/g, `\n${pad}`);
}

function trimBlank(lines) {
  let a = 0;
  let b = lines.length;
  while (a < b && lines[a] === "") a++;
  while (b > a && lines[b - 1] === "") b--;
  return lines.slice(a, b);
}

const sameColon = (a, b) => {
  const ca = a.getColon();
  const cb = b.getColon();
  return ca && cb && ca.getRow() === cb.getRow() && ca.getCol() === cb.getCol();
};

const findTo = (s) => children(s, "Target").length > 0;

/** the name a declaration declares */
export function declName(s) {
  const k = kind(s);
  if (k === "Data" || k === "Constant" || k === "Static" || k === "ClassData") {
    const dd = child(s, "DataDefinition") ?? s;
    const n = child(dd, "DefinitionName") ?? findAll(s, "DefinitionName")[0];
    return n ? nodeText(n) : undefined;
  }
  if (["DataBegin", "DataEnd", "TypeBegin", "TypeEnd", "ConstantBegin", "ConstantEnd", "Ranges", "Type", "StaticBegin"].includes(k)) {
    const n = findAll(s, "DefinitionName")[0] ?? findAll(s, "NamespaceSimpleName")[0];
    return n ? nodeText(n) : undefined;
  }
  if (k === "Parameter" || k === "SelectOption") return nodeText(child(s, "FieldSub"));
  if (k === "Tables") return nodeText(child(s, "Field"));
  if (k === "FieldSymbol") return nodeText(child(s, "FieldSymbol"));
  if (k === "MethodDef") return nodeText(child(s, "MethodName"));
  return undefined;
}

/** zflight_list -> zcl_flight_list, /abc/flights -> /abc/cl_flights */
export function defaultClassName(program) {
  const p = lc(program);
  const ns = /^(\/\w+\/)(.*)$/.exec(p);
  if (ns) return `${ns[1]}cl_${ns[2]}`.slice(0, 30);
  const m = /^([zy])_?(.*)$/.exec(p);
  return (m ? `${m[1]}cl_${m[2]}` : `zcl_${p}`).slice(0, 30);
}

/** a call chain over a variable: target = root->a( )->b( arg ). */
function salvChain(s) {
  const k = kind(s);
  if (k !== "Call" && k !== "Move") return undefined;
  const toks = stmtTokens(s).map((t) => t.getStr());
  let i = 0;
  let target;
  if (k === "Move") {
    if (toks[1] !== "=" && toks[1] !== "?=") return undefined;
    target = lc(toks[0]);
    i = 2;
    // CAST cl_salv_column_table( x->get_column( 'A' ) )
    if (lc(toks[i]) === "cast" && toks[i + 2] === "(") {
      const inner = toks.slice(i + 3, -1);
      const r = chainOf(inner);
      return r ? { target, ...r } : undefined;
    }
  }
  if (k === "Call" && uc(toks[0]) === "CALL" && uc(toks[1]) === "METHOD") {
    // CALL METHOD x->display.
    const rest = toks.slice(2);
    if (rest.length === 3 && rest[1] === "->") return { root: lc(rest[0]), calls: [{ name: lc(rest[2]) }] };
    return undefined;
  }
  const r = chainOf(toks.slice(i));
  return r ? { target, ...r } : undefined;
}

function chainOf(toks) {
  if (!toks.length || !/^[\w/]+$/.test(toks[0])) return undefined;
  const root = lc(toks[0]);
  const calls = [];
  let i = 1;
  while (i < toks.length) {
    if (toks[i] !== "->" || !toks[i + 1] || toks[i + 2] !== "(") return undefined;
    const name = lc(toks[i + 1]);
    let depth = 0;
    let j = i + 2;
    const arg = [];
    for (; j < toks.length; j++) {
      if (toks[j] === "(" || toks[j].endsWith("(")) depth++;
      if (toks[j] === ")" || toks[j].startsWith(")")) depth--;
      if (depth === 0) break;
      if (j > i + 2) arg.push(toks[j]);
    }
    const argText = arg.join(" ").replace(/^value\s*=\s*/i, "").trim();
    calls.push({ name, arg: argText || undefined });
    i = j + 1;
  }
  return calls.length ? { root, calls } : undefined;
}

/** the parameters of CALL FUNCTION, by lower case name */
function functionParams(s) {
  const out = new Map();
  for (const k of ["FunctionExportingParameter", "ParameterS", "ParameterT"]) {
    for (const p of findAll(s, k)) {
      const name = lc(nodeText(child(p, "ParameterName")));
      const value = children(p).find((c) => kind(c) !== "ParameterName");
      out.set(name, { node: value });
    }
  }
  return out;
}

/** CASE field. WHEN `A`. ... ENDCASE. */
function caseBody(param, entries) {
  const body = [`CASE ${param}.`];
  for (const e of entries) body.push(`  WHEN ${literal(e.field)}.`, ...e.body.map((l) => indent(l, 4)));
  body.push("ENDCASE.");
  return body;
}

function renderCall(method, imp, chg) {
  if (!imp.length && !chg.length) return `${method}( ).`;
  if (!chg.length && imp.length === 1) return `${method}( ${imp[0].value} ).`;
  if (!chg.length) return renderNamedCall(method, imp);
  const width = Math.max(...[...imp, ...chg].map((p) => p.name.length));
  const head = `${method}( `;
  const pad = " ".repeat(head.length);
  const lines = [];
  if (imp.length) {
    lines.push(`${head}EXPORTING`);
    for (const p of imp) lines.push(`${pad}  ${p.name.padEnd(width)} = ${p.value}`);
    lines.push(`${pad}CHANGING`);
  } else {
    lines.push(`${head}CHANGING`);
  }
  for (const p of chg) lines.push(`${pad}  ${p.name.padEnd(width)} = ${p.value}`);
  lines[lines.length - 1] += " ).";
  return lines.join("\n");
}

function renderNamedCall(method, params) {
  if (params.length === 1 && !params[0].name) return `${method}( ${params[0].value} ).`;
  const width = Math.max(...params.map((p) => p.name.length));
  const head = `${method}( `;
  return params.map((p, i) => `${i ? " ".repeat(head.length) : head}${p.name.padEnd(width)} = ${p.value}`).join("\n") + " ).";
}

/**
 * A call chain in the house layout of the samples: one call per line, the
 * parameters of a call aligned under each other.
 *
 *   write( val     = ls_flight-carrid
 *          hotspot = abap_true
 *       )->write( ls_flight-connid
 *       )->new_line( ).
 */
function renderChain(chain) {
  const items = chain.items.map((it) => {
    const params = it.params.filter((p) => p.value !== undefined);
    // one parameter is written without its name, as omit_parameter_name asks
    const named = params.length > 1 || (params.length === 1 && params[0].name && params[0].name !== "val" && !it.positional && it.method !== "skip");
    return { ...it, params, named };
  });
  const lines = [];
  items.forEach((it, idx) => {
    const last = idx === items.length - 1;
    let head;
    if (idx === 0) head = ["write", "alv"].includes(it.method) ? `${it.method}(` : `list( )->${it.method}(`;
    else head = `    )->${it.method}(`;
    if (!it.params.length) {
      lines.push(last ? `${head} ).` : head);
      return;
    }
    if (!it.named) {
      lines.push(`${head} ${it.params[0].value}${last ? " )." : ""}`);
      return;
    }
    const width = Math.max(...it.params.map((p) => p.name.length));
    it.params.forEach((p, i) => {
      const prefix = i === 0 ? `${head} ` : " ".repeat(head.length + 1);
      lines.push(`${prefix}${p.name.padEnd(width)} = ${p.value}${last && i === it.params.length - 1 ? " )." : ""}`);
    });
  });
  return [lines.join("\n")];
}

/** the chain of selection_screen( ), as the painter writes it */
function renderScreenChain(calls) {
  if (!calls.length) return [];
  const lines = [];
  calls.forEach((c, idx) => {
    const last = idx === calls.length - 1;
    const head = idx === 0 ? `screen->${c.method}(` : `    )->${c.method}(`;
    const named = c.params.length > 1 || (c.params.length === 1 && !c.positional && c.params[0].name !== "val");
    if (!c.params.length) {
      lines.push(last ? `${head} ).` : head);
      return;
    }
    if (!named) {
      lines.push(`${head} ${c.params[0].value}${last ? " )." : ""}`);
      return;
    }
    const width = Math.max(...c.params.map((p) => p.name.length));
    c.params.forEach((p, i) => {
      const prefix = i === 0 ? `${head} ` : " ".repeat(head.length + 1);
      lines.push(`${prefix}${p.name.padEnd(width)} = ${p.value}${last && i === c.params.length - 1 ? " )." : ""}`);
    });
  });
  return [lines.join("\n")];
}

/** convert a classic report into an abap-cloud-gui report class */
export function convert(source, opts = {}) {
  return new Converter(source, opts).run();
}
