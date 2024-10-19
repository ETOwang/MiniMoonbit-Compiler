pub typealias LocalEnv = @immut/hashmap.T[String, Type]

// Assuming Op is defined in a module named 'operations'

struct KnfEnv {
  mut counter : Int
  externals : @immut/hashmap.T[String, Type]
}

pub fn KnfEnv::new(externals : @immut/hashmap.T[String, Type]) -> KnfEnv {
  { counter: 1, externals }
}

pub fn KnfEnv::init_counter_from_existing(
  self : KnfEnv,
  existing : Knf
) -> Unit {
  self.counter = knf_max_counter(existing) + 1
}

fn KnfEnv::new_temp(self : KnfEnv) -> Name {
  let temp = Name::slot_only(self.counter)
  self.counter += 1
  temp
}

fn KnfEnv::new_named_temp(self : KnfEnv, name : Name) -> Name {
  let counter = self.counter
  self.counter += 1
  { ..name, slot: counter }
}

pub fn KnfEnv::to_knf!(self : KnfEnv, s : @types.Syntax) -> Knf { 
  match s {
    Unit => Knf::Unit
    Int(i) => Knf::Int(i)
    Bool(b) => Knf::Int(if b { 1 } else { 0 })
    Double(d) => Knf::Double(d)
    Neg(x, ..) => Knf::Neg(new_named_temp(self, @types.Name::from_string!(x.to_string())))
    Var(x) => Knf::Var(new_named_temp(self, @types.Name::from_string!(x)))
    Tuple(xs) => {
      let names: Array[Name] = Array::new()
      for x in xs {
        names.push(new_named_temp(self, @types.Name::from_string!(x.to_string())))
      }
      Knf::Tuple(names)
    }
    Prim(a, b, op, ..) => {
      if op == @types.Op::Add {
        let a_name:@types.Name = new_named_temp(self, @types.Name::from_string!(a.to_string()))
        let b_name:@types.Name = new_named_temp(self, @types.Name::from_string!(b.to_string()))
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf!(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf!(self, b), 
            Knf:: Add(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Sub {
        let a_name:@types.Name = new_named_temp(self, @types.Name::from_string!(a.to_string()))
        let b_name:@types.Name = new_named_temp(self, @types.Name::from_string!(b.to_string()))
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf!(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf!(self, b), 
            Knf:: Sub(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Mul {
        let a_name:@types.Name = new_named_temp(self, @types.Name::from_string!(a.to_string()))
        let b_name:@types.Name = new_named_temp(self, @types.Name::from_string!(b.to_string()))
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf!(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf!(self, b), 
            Knf:: Mul(a_name, b_name)
          )
        )
      }
      else if op == @types.Op::Div {
        let a_name:@types.Name = new_named_temp(self, @types.Name::from_string!(a.to_string()))
        let b_name:@types.Name = new_named_temp(self, @types.Name::from_string!(b.to_string()))
        Knf:: Let((a_name, getTypeFromSynax(a)), to_knf!(self, a), 
          Knf:: Let((b_name, getTypeFromSynax(b)), to_knf!(self, b), 
            Knf:: Div(a_name, b_name)
          )
        )
      }
      else {
        abort("todo")
      }
    }
  }
  // abort("todo")

}
