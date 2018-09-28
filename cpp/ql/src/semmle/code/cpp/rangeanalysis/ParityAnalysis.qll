import cpp
import semmle.code.cpp.ir.IR
import semmle.code.cpp.controlflow.IRGuards
import semmle.code.cpp.ir.ValueNumbering
import semmle.code.cpp.rangeanalysis.SignAnalysis

/** Gets an instruction that is the remainder modulo 2 of `arg` */
private Instruction mod2(Instruction arg) {
  exists(RemInstruction ri |
    result = ri and
    ri.getLeftOperand() = arg and
    ri.getRightOperand().(ConstantValueInstruction).getValue().toInt() = 2
  )
  or
  result.(BitAndInstruction).getRightOperand() = arg and
  result.(BitAndInstruction).getLeftOperand().(ConstantValueInstruction).getValue().toInt() = 1
  or
  result.(BitAndInstruction).getLeftOperand() = arg and
  result.(BitAndInstruction).getRightOperand().(ConstantValueInstruction).getValue().toInt() = 1
}

private class Mod2 extends Instruction {
  Mod2() {
    this = mod2(_)
  }
  
  Instruction getArg() {
    this = mod2(result)
  }
}

class Parity extends boolean {
  Parity() {
    this = true
    or
    this = false
  }
  
  predicate isEven() {
    this = false
  }
  
  predicate isOdd() {
    this = true
  }
}

/**
 * Gets a condition that performs a parity check on `i` at `use, such that `i` has
 * the given parity if the condition evaluates to `testIsTrue`.
 */
private IRGuardCondition parityCheck(Instruction i, Instruction use, Parity parity, boolean testIsTrue) {
  (
    // binding
    testIsTrue = true or
    testIsTrue = false
  ) and
  exists(Mod2 rem, IntegerConstantInstruction ici, int r, boolean polarity |
    result.ensuresEq(rem, ici, 0, use.getBlock(), polarity) and
    ici.getValue().toInt() = r and
    i = use.getAnOperand() and
    rem.getArg() = valueNumber(i).getAnInstruction() and
    (
      r = 0 and parity = testIsTrue.booleanXor(polarity)
      or
      r = 1 and parity = testIsTrue.booleanXor(polarity).booleanNot()
    )
  )
}


/**
 * Gets the parity of `i` at `use` if it can be directly determined.
 */
private Parity certainInstructionParity(Instruction i, Instruction use) {
  exists(int j | i.(ConstantInstruction).getValue().toInt() = j |
    if j % 2 = 0 then result.isEven() else result.isOdd()
  )
  // Java library has logic for long literals here
  or
  not exists (i.(ConstantInstruction).getValue().toInt()) and
  exists(IRGuardCondition gc, boolean testIsTrue |
    gc = parityCheck(i, use, testIsTrue, testIsTrue)
  )
}

/** Holds if the parity of `i` is too complicated to determine. */
private predicate unknownParity(Instruction i) {
  i instanceof DivInstruction
  or
  i instanceof ShiftRightInstruction
  or
  i instanceof UnmodeledDefinitionInstruction
  or
  i.getResultType() instanceof FloatingPointType
  or
  exists(Type fromType |
    i.(ConvertInstruction).getOperand().getResultType() = fromType and
    not fromType instanceof IntegralType
  )
}

/** Gets a possible parity for `i` at `use`. */
private Parity instructionParity(Instruction i, Instruction use) {
  result = certainInstructionParity(i, use)
  or
  not exists(certainInstructionParity(i, use)) and
  (
    result = instructionParity(i.(CopyInstruction).getSourceValue(), use)
    or
    result = instructionParity(i.(NegateInstruction).getOperand(), use)
    or
    result = instructionParity(i.(BitComplementInstruction).getOperand(), use).booleanNot()
    or
    unknownParity(i) and (result = true or result = false)
    or
    exists(Parity p1, Parity p2, BinaryInstruction bin |
      bin = i and
      p1 = instructionParity(bin.getLeftOperand(), use) and
      p2 = instructionParity(bin.getRightOperand(), use)
      |
      bin instanceof AddInstruction and result = p1.booleanXor(p2)
      or
      bin instanceof SubInstruction and result = p1.booleanXor(p2)
      or
      bin instanceof MulInstruction and result = p1.booleanAnd(p2)
      or
      bin instanceof RemInstruction and
      (
        p2.isEven() and result = p1
        or
        p2.isOdd() and (result = true or result = false)
      )
      or
      bin instanceof BitAndInstruction and result = p1.booleanAnd(p2)
      or
      bin instanceof BitOrInstruction and result = p1.booleanOr(p2)
      or
      bin instanceof BitXorInstruction and result = p1.booleanXor(p2)
      or
      bin instanceof ShiftLeftInstruction and (result.isEven() or result = p1 and not strictlyPositive(bin.getRightOperand()))
    )
    or
    result = instructionParity(i.(PhiInstruction).getAnOperand(), use)
    or
    result = instructionParity(i.(ConvertInstruction).getOperand(), use)
  )
}

/**
 * Gets the parity of `i` at `use` if it can be uniquely determined.
 */
Parity getInstructionParity(Instruction i, Instruction use) {
  result = instructionParity(i, use) and 1 = count(instructionParity(i, use))
}

/**
 * Holds if the parity can be determined for both sides of `ri`. The boolean
 * `eqparity` indicates whether the two sides have equal or opposite parity.
 */
predicate parityComparison(RelationalInstruction ri, boolean eqparity) {
  exists(Instruction left, Instruction right, boolean lpar, boolean rpar |
    ri.getLeftOperand() = left and
    ri.getRightOperand() = right and
    lpar = getInstructionParity(left, ri) and
    rpar = getInstructionParity(right, ri) and
    eqparity = lpar.booleanXor(rpar).booleanNot()
  ) 
}