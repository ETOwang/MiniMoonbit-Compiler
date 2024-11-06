/// The stage to be run next.
enum Stages {
  Parse
  Typecheck
  Knf
  KnfOpt
  Closure
  Asm
  Js
  Wasm
  Finished
} derive(Show, Eq, Compare)

fn Stages::from_string(s : String) -> Stages? {
  match s {
    "parse" => Some(Stages::Parse)
    "js" => Some(Stages::Js)
    "typecheck" => Some(Stages::Typecheck)
    "knf" => Some(Stages::Knf)
    "knf-opt" => Some(Stages::KnfOpt)
    "closure" => Some(Stages::Closure)
    "riscv" => Some(Stages::Asm)
    "wasm" => Some(Stages::Wasm)
    "finished" => Some(Stages::Finished)
    _ => None
  }
}

fn Stages::next(self : Stages, js_mode: Bool, wasm_mode: Bool) -> Stages {
  if js_mode {
    match self {
      Stages::Parse => Stages::Js
      Stages::Js => Stages::Finished
      Stages::Finished => Stages::Finished
    }
  }
  else if wasm_mode {
    match self {
      Stages::Parse => Stages::Typecheck
      Stages::Typecheck => Stages::Knf
      Stages::Knf => Stages::KnfOpt
      Stages::KnfOpt => Stages::Closure
      Stages::Closure => Stages::Wasm
      Stages::Wasm => Stages::Finished
      Stages::Finished => Stages::Finished
    }
  }
  else {
    match self {
      Stages::Parse => Stages::Typecheck
      Stages::Typecheck => Stages::Knf
      Stages::Knf => Stages::KnfOpt
      Stages::KnfOpt => Stages::Closure
      Stages::Closure => Stages::Asm
      Stages::Asm => Stages::Finished
      Stages::Finished => Stages::Finished
    }
  }
}

struct CompileStatus {
  mut curr_stage : Stages
  end_stage : Stages
  mut source_code : String?
  mut ast : @types.Syntax?
  mut typechecked : @types.Syntax?
  knf_env : @knf.KnfEnv
  mut knf : @knf.Knf?
  mut opt_knf : @knf.Knf?
  mut closure_ir : @closure.Program?
  mut asm : Array[@riscv.AssemblyFunction]?
  mut js_code : String?
  mut wasm : String?
}

fn CompileStatus::initialize(
  start_stage : Stages,
  end_stage : Stages,
  file : String
) -> CompileStatus! {
  let v = CompileStatus::{
    curr_stage: start_stage,
    end_stage,
    source_code: None,
    ast: None,
    typechecked: None,
    knf_env: @knf.KnfEnv::new(externals()),
    knf: None,
    opt_knf: None,
    closure_ir: None,
    asm: None,
    js_code: None,
    wasm: None
  }
  match start_stage {
    Parse => v.source_code = Some(file)
    Typecheck => v.ast = Some(@types.Syntax::from_json!(@json.parse!(file)))
    Knf => v.typechecked = Some(@types.Syntax::from_json!(@json.parse!(file)))
    KnfOpt => {
      v.knf = Some(@knf.Knf::from_json!(@json.parse!(file)))
      v.knf_env.init_counter_from_existing(v.knf.unwrap())
    }
    Closure => {
      v.opt_knf = Some(@knf.Knf::from_json!(@json.parse!(file)))
      v.knf_env.init_counter_from_existing(v.opt_knf.unwrap())
    }
    _ => fail!("invalid start stage")
  }
  v
}

/// Run the next stage of compilation. Returns true if the compilation is finished.
fn CompileStatus::step(self : CompileStatus, js_mode: Bool, wasm_mode: Bool) -> Bool {
  if self.curr_stage >= self.end_stage {
    return true
  }
  match self.curr_stage {
    Parse => {
      let source_code = self.source_code.unwrap()
      let parsed = @parser.parse(source_code)
      self.ast = Some(parsed)
    }
    Typecheck => {
      let typechecked = @typing.wrapper(self.ast.unwrap())
      self.typechecked = Some(typechecked)
    }
    Knf => {
      let knf = self.knf_env.to_knf(self.typechecked.unwrap())
      self.knf = Some(knf)
    }
    KnfOpt => {
      let knf = self.knf.unwrap()
      // TODO: optimize
      self.opt_knf = Some(knf)
    }
    Closure => {
      let closure_ir = @closure.knf_program_to_closure(
        self.opt_knf.unwrap(),
        Map::from_iter(externals().iter()),
      )
      self.closure_ir = Some(closure_ir)
    }
    Asm => {
      let real_asm = @riscv.emit(@util.die("TODO"))
      self.asm = Some(real_asm)
    }
    Js => {
      let code = @js.generator(self.ast.unwrap())
      self.js_code = Some(code)
    }
    Wasm => {
      let wasm = @wasm.generator(self.closure_ir.unwrap())
      self.wasm = Some(wasm)
    }
    Finished => ()
  }
  self.curr_stage = self.curr_stage.next(js_mode, wasm_mode)
  self.curr_stage >= self.end_stage
}

fn CompileStatus::output(self : CompileStatus, json : Bool) -> String {
  if json {
    match self.curr_stage {
      Parse => self.source_code.unwrap()
      Typecheck => @json.stringify(self.ast.unwrap().to_json())
      Knf => @json.stringify(self.typechecked.unwrap().to_json())
      KnfOpt => @json.stringify(self.knf.unwrap().to_json())
      Closure => @json.stringify(self.opt_knf.unwrap().to_json())
      Asm => @util.die("TODO")
      Js => self.js_code.unwrap()
      Wasm => self.wasm.unwrap()
      Finished => @riscv.print_functions(self.asm.unwrap())
    }
  } else {
    match self.curr_stage {
      Parse => self.source_code.unwrap()
      Typecheck => self.ast.unwrap().to_string()
      Knf => self.typechecked.unwrap().to_string()
      KnfOpt => self.knf.unwrap().to_string()
      Closure => self.opt_knf.unwrap().to_string()
      Asm => @util.die("TODO")
      Js => self.js_code.unwrap().to_string()
      Wasm => self.wasm.unwrap().to_string()
      Finished => @riscv.print_functions(self.asm.unwrap())
    }
  }
}

fn main {
  let argv = @env.get_args()
  let mut file = None
  let knf_opt_iters = Ref::new(10)
  let knf_opt_inline_threshold = Ref::new(10)

  // Testing directives
  let json = Ref::new(false)
  let start_stage = Ref::new(Stages::Parse)
  let end_stage = Ref::new(Stages::Finished)
  let knf_interpreter = Ref::new(false)
  let closure_interpreter = Ref::new(false)
  let out_file = Ref::new("-")
  let print = Ref::new([])
  let js_mode = Ref::new(false)
  let wasm_mode = Ref::new(false)
  // 
  @ArgParser.parse(
    [
      (
        "--start-stage",
        "",
        @ArgParser.String(
          fn(s) {
            match Stages::from_string(s) {
              Some(stage) => start_stage.val = stage
              None => @util.die("Invalid stage")
            }
          },
        ),
        "Start stage",
      ),
      (
        "--end-stage",
        "",
        @ArgParser.String(
          fn(s) {
            match Stages::from_string(s) {
              Some(stage) => end_stage.val = stage
              None => @util.die("Invalid stage")
            }
          },
        ),
        "End stage",
      ),
      (
        "--knf-interpreter",
        "",
        @ArgParser.Set(knf_interpreter),
        "Run with KNF interpreter",
      ),
      (
        "--closure-interpreter",
        "",
        @ArgParser.Set(closure_interpreter),
        "Run with closure interpreter",
      ),
      (
        "--out-file",
        "-o",
        @ArgParser.String(fn(s) { out_file.val = s }),
        "Output file",
      ),
      (
        "--js",
        "",
        @ArgParser.Set(js_mode),
        "Generate Js code",
      ),
      (
        "--wasm",
        "",
        @ArgParser.Set(wasm_mode),
        "Generate  wasm",
      ),
      ("--json", "", @ArgParser.Set(json), "Print results as JSON"),

      // Regular directives
      (
        "--print",
        "",
        @ArgParser.String(fn(s) { print.val = s.split(",").collect() }),
        "",
      ),
      (
        "--knf-opt-iters",
        "N",
        @ArgParser.String(
          fn(s) {
            let i = @strconv.parse_int?(s)
            match i {
              Ok(i) => knf_opt_iters.val = i
              Err(e) => @util.die("Invalid number")
            }
          },
        ),
        "Number of optimization iterations",
      ),
      (
        "--knf-opt-inline-threshold",
        "N",
        @ArgParser.String(
          fn(s) {
            let i = @strconv.parse_int?(s)
            match i {
              Ok(i) => knf_opt_inline_threshold.val = i
              Err(e) => @util.die("Invalid number")
            }
          },
        ),
        "Inline threshold for KNF optimization",
      ),
      
    ],
    fn(s) {
      if file.is_empty().not() {
        @util.die("multiple files are given")
      }
      file = Some(s)
    },
    "",
    argv,
  )

  // Configure pipeline
  if knf_interpreter.val {
    end_stage.val = Stages::Knf
  }
  if closure_interpreter.val {
    end_stage.val = Stages::Closure
  }
  if js_mode.val {
    end_stage.val = Stages::Js
  }
  if wasm_mode.val {
    end_stage.val = Stages::Wasm
  }
  let stages_to_print = print.val.map(
    fn(s) {
      match Stages::from_string(s) {
        Some(stage) => stage
        None => @util.die("Invalid stage to print: \{s}")
      }
    },
  )

  // Input
  let file = if file.is_empty() {
    @util.die("no input file provided")
  } else {
    file.unwrap()
  }
  let contents = @fs.read_to_string(file)

  // Compilation
  let status = match
    CompileStatus::initialize?(start_stage.val, end_stage.val.next(js_mode.val, wasm_mode.val), contents) {
    Ok(status) => status
    Err(e) => {
      println(e)
      @util.die("Initialization error")
    }
  }
  // Run stages
  while true {
    let stg = status.curr_stage
    let stop = status.step(js_mode.val, wasm_mode.val)
    if stages_to_print.contains(stg) {
      println("Stage: \{stg}")
      println(status.output(json.val))
    }
    if stop {
      break
    }
  }

  // Output
  if knf_interpreter.val {
    let knfi = @knf_eval.KnfInterpreter::new()
    add_interpreter_fns(knfi)
    match knfi.eval_full?(status.knf.unwrap()) {
      Ok(_) => ()
      Err(Failure(e)) => {
        println(e)
        @util.die("KNF interpreter error")
      }
    }
  } else if closure_interpreter.val {
    let clsi = @closure_eval.ClosureInterpreter::new()
    add_closure_interpreter_fns(clsi)
    match clsi.eval_full?(status.closure_ir.unwrap()) {
      Ok(_) => ()
      Err(Failure(e)) => {
        println(e)
        @util.die("Closure interpreter error")
      }
    }
  } else if js_mode.val {
    let js_code = status.js_code
    if out_file.val == "-" {
      println(js_code.unwrap())
    } else {
      @fs.write_to_string(out_file.val, js_code.unwrap())
    }
  } else if wasm_mode.val {
    let wasm_code = status.wasm
    if out_file.val == "-" {
      println(wasm_code.unwrap())
    } else {
      @fs.write_to_string(out_file.val, wasm_code.unwrap())
    }
  } else {
    let out_string = status.output(json.val)
    if out_file.val == "-" {
      println(out_string)
    } else {
      @fs.write_to_string(out_file.val, out_string)
    }
  }
  
}
