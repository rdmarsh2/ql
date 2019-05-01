import cpp
private import semmle.code.cpp.ir.implementation.Opcode
private import semmle.code.cpp.ir.internal.OperandTag
private import semmle.code.cpp.models.interfaces.SideEffect
private import InstructionTag
private import TranslatedElement
private import TranslatedExpr
private import TranslatedFunction

/**
 * The IR translation of a call to a function. The call may be from an actual
 * call in the source code, or could be a call that is part of the translation
 * of a higher-level constructor (e.g. the allocator call in a `NewExpr`).
 */
abstract class TranslatedCall extends TranslatedExpr {
  override final TranslatedElement getChild(int id) {
    // We choose the child's id in the order of evaluation.
    // The qualifier is evaluated before the call target, because the value of
    // the call target may depend on the value of the qualifier for virtual
    // calls.
    id = -2 and result = getQualifier() or
    id = -1 and result = getCallTarget() or
    result = getArgument(id) or
    id = getNumberOfArguments() and result = getSideEffects()
  }

  override final Instruction getFirstInstruction() {
    if exists(getQualifier()) then
      result = getQualifier().getFirstInstruction()
    else
      result = getFirstCallTargetInstruction()
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    (
      tag = CallTag() and
      opcode instanceof Opcode::Call and
      resultType = getCallResultType() and
      isGLValue = false
    ) or
    (
      hasSideEffect() and
      tag = CallSideEffectTag() and
      (
        if hasWriteSideEffect() then (
          opcode instanceof Opcode::CallSideEffect and
          resultType instanceof UnknownType
        )
        else (
          opcode instanceof Opcode::CallReadSideEffect and
          resultType instanceof VoidType
        )
      ) and
      isGLValue = false
    )
  }
  
  override Instruction getChildSuccessor(TranslatedElement child) {
    (
      child = getQualifier() and
      result = getFirstCallTargetInstruction()
    ) or
    (
      child = getCallTarget() and
      result = getFirstArgumentOrCallInstruction()
    ) or
    exists(int argIndex |
      child = getArgument(argIndex) and
      if exists(getArgument(argIndex + 1)) then
        result = getArgument(argIndex + 1).getFirstInstruction()
      else
        result = getInstruction(CallTag())
    ) or
		(
		   child = getSideEffects() and
			 result = getParent().getChildSuccessor(this)
		)
  }

  override Instruction getInstructionSuccessor(InstructionTag tag,
    EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      (
        tag = CallTag() and
        if hasSideEffect() then
          result = getInstruction(CallSideEffectTag())
        else if hasPreciseSideEffect() then
          result = getSideEffects().getFirstInstruction()
        else
          result =  getParent().getChildSuccessor(this) 
      ) or
      (
        hasSideEffect() and
        tag = CallSideEffectTag() and
        if hasPreciseSideEffect() then
          result = getSideEffects().getFirstInstruction()
        else
          result =  getParent().getChildSuccessor(this) 
      )
    )
  }

  override Instruction getInstructionOperand(InstructionTag tag,
      OperandTag operandTag) {
    (
      tag = CallTag() and
      (
        (
          operandTag instanceof CallTargetOperandTag and
          result = getCallTargetResult()
        ) or
        (
          operandTag instanceof ThisArgumentOperandTag and
          result = getQualifierResult()
        ) or
        exists(PositionalArgumentOperandTag argTag |
          argTag = operandTag and
          result = getArgument(argTag.getArgIndex()).getResult()
        )
      )
    ) or
    (
      tag = CallSideEffectTag() and
      hasSideEffect() and
      operandTag instanceof SideEffectOperandTag and
      result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
    )
  }

  override final Type getInstructionOperandType(InstructionTag tag,
      TypedOperandTag operandTag) {
    tag = CallSideEffectTag() and
    hasSideEffect() and
    operandTag instanceof SideEffectOperandTag and
    result instanceof UnknownType
  }

  override final Instruction getResult() {
    result = getInstruction(CallTag())
  }

  /**
   * Gets the result type of the call.
   */
  abstract Type getCallResultType();

  /**
   * Holds if the call has a `this` argument.
   */
  predicate hasQualifier() {
    exists(getQualifier())
  }

  /**
   * Gets the `TranslatedExpr` for the indirect target of the call, if any.
   */
  TranslatedExpr getCallTarget() {
    none()
  }

  /**
   * Gets the first instruction of the sequence to evaluate the call target.
   * By default, this is just the first instruction of `getCallTarget()`, but
   * it can be overridden by a subclass for cases where there is a call target
   * that is not computed from an expression (e.g. a direct call).
   */
  Instruction getFirstCallTargetInstruction() {
    result = getCallTarget().getFirstInstruction()
  }

  /**
   * Gets the instruction whose result value is the target of the call. By
   * default, this is just the result of `getCallTarget()`, but it can be
   * overridden by a subclass for cases where there is a call target that is not
   * computed from an expression (e.g. a direct call).
   */
  Instruction getCallTargetResult() {
    result = getCallTarget().getResult()
  }

  /**
   * Gets the `TranslatedExpr` for the qualifier of the call (i.e. the value
   * that is passed as the `this` argument.
   */
  abstract TranslatedExpr getQualifier();

  /**
   * Gets the instruction whose result value is the `this` argument of the call.
   * By default, this is just the result of `getQualifier()`, but it can be
   * overridden by a subclass for cases where there is a `this` argument that is
   * not computed from a child expression (e.g. a constructor call).
   */
  Instruction getQualifierResult() {
    result = getQualifier().getResult()
  }

  /**
   * Gets the argument with the specified `index`. Does not include the `this`
   * argument.
   */
  abstract TranslatedExpr getArgument(int index);

  abstract int getNumberOfArguments();

  /**
   * If there are any arguments, gets the first instruction of the first
   * argument. Otherwise, returns the call instruction.
   */
  final Instruction getFirstArgumentOrCallInstruction() {
    if hasArguments() then
      result = getArgument(0).getFirstInstruction()
    else
      result = getInstruction(CallTag())
  }

  /**
   * Holds if the call has any arguments, not counting the `this` argument.
   */
  abstract predicate hasArguments();

  predicate hasReadSideEffect() {
    any()
  }

  predicate hasWriteSideEffect() {
    any()
  }

  private predicate hasSideEffect() {
    hasReadSideEffect() or hasWriteSideEffect()
  }
  override Instruction getPrimaryInstructionForSideEffect(InstructionTag tag) {
      hasSideEffect() and
      tag = CallSideEffectTag() and
      result = getResult()
	}

	predicate hasPreciseSideEffect() {
    exists(getSideEffects())
  }
  
  TranslatedSideEffects getSideEffects() {
    result.getCall() = expr
  }
}

/**
 * IR translation of a direct call to a specific function. Used for both
 * explicit calls (`TranslatedFunctionCall`) and implicit calls
 * (`TranslatedAllocatorCall`).
 */
abstract class TranslatedDirectCall extends TranslatedCall {
  override final Instruction getFirstCallTargetInstruction() {
    result = getInstruction(CallTargetTag())
  }

  override final Instruction getCallTargetResult() {
    result = getInstruction(CallTargetTag())
  }

  override predicate hasInstruction(Opcode opcode, InstructionTag tag,
      Type resultType, boolean isGLValue) {
    TranslatedCall.super.hasInstruction(opcode, tag, resultType, isGLValue) or
    (
      tag = CallTargetTag() and
      opcode instanceof Opcode::FunctionAddress and
      // The database does not contain a `FunctionType` for a function unless
      // its address was taken, so we'll just use glval<Unknown> instead of
      // glval<FunctionType>.
      resultType instanceof UnknownType and
      isGLValue = true
    )
  }
  
  override Instruction getInstructionSuccessor(InstructionTag tag,
      EdgeKind kind) {
    result = TranslatedCall.super.getInstructionSuccessor(tag, kind) or
    (
      tag = CallTargetTag() and
      kind instanceof GotoEdge and
      result = getFirstArgumentOrCallInstruction()
    )
  }
}

/**
 * The IR translation of a call to a function.
 */
abstract class TranslatedCallExpr extends TranslatedNonConstantExpr,
    TranslatedCall {
  override Call expr;

  override final Type getCallResultType() {
    result = getResultType()
  }

  override final predicate hasArguments() {
    exists(expr.getArgument(0))
  }

  override final TranslatedExpr getQualifier() {
    result = getTranslatedExpr(expr.getQualifier().getFullyConverted())
  }

  override final TranslatedExpr getArgument(int index) {
    result = getTranslatedExpr(expr.getArgument(index).getFullyConverted())
  }

  override final int getNumberOfArguments() {
    result = expr.getNumberOfArguments()
  }
}

/**
 * Represents the IR translation of a call through a function pointer.
 */
class TranslatedExprCall extends TranslatedCallExpr {
  override ExprCall expr;

  override TranslatedExpr getCallTarget() {
    result = getTranslatedExpr(expr.getExpr().getFullyConverted())
  }
}

/**
 * Represents the IR translation of a direct function call.
 */
class TranslatedFunctionCall extends TranslatedCallExpr, TranslatedDirectCall {
  override FunctionCall expr;

  override Function getInstructionFunction(InstructionTag tag) {
    tag = CallTargetTag() and result = expr.getTarget()
  }

  override predicate hasReadSideEffect() {
    not expr.getTarget().(SideEffectFunction).neverReadsMemory()
  }

  override predicate hasWriteSideEffect() {
    not expr.getTarget().(SideEffectFunction).neverWritesMemory()
  }
	
	override predicate hasPreciseSideEffect() {
    expr.getTarget().(SideEffectFunction).hasSpecificReadSideEffect(_, _)
		or
    expr.getTarget().(SideEffectFunction).hasSpecificWriteSideEffect(_, _, _)
  }
}

/**
 * Represents the IR translation of a call to a constructor.
 */
class TranslatedStructorCall extends TranslatedFunctionCall {
  TranslatedStructorCall() {
    expr instanceof ConstructorCall or
    expr instanceof DestructorCall
  }

  override Instruction getQualifierResult() {
    exists(StructorCallContext context |
      context = getParent() and
      result = context.getReceiver()
    )
  }

  override predicate hasQualifier() {
    any()
  }
}


class TranslatedSideEffects extends TranslatedElement, TTranslatedSideEffects {
  Call expr;
  
  TranslatedSideEffects() {
    this = TTranslatedSideEffects(expr)
  }

  override string toString() {
    result = "(side effects  for " + expr.toString() + ")"
  }
  
  override Locatable getAST() {
    result = expr
  }

  Call getCall() {
    result = expr
  }

  override TranslatedElement getChild(int i) {
    result = rank[i+1](TranslatedSideEffect tse, int isWrite, int index |
      (
        tse.getCall() = getCall() and
				tse.getArgumentIndex() = index and
				if tse.isWrite()
				then isWrite = 1
				else isWrite = 0
      )
      |
      tse order by isWrite, index
    )
	}

  override Instruction getChildSuccessor(TranslatedElement te) {
    exists(int i | getChild(i) = te and
      if exists(getChild(i + 1)) then
        result = getChild(i + 1).getFirstInstruction()
      else
        result = getParent().getChildSuccessor(this)
    )
  }

	override predicate hasInstruction(Opcode opcode, InstructionTag tag, Type t, boolean isGLValue) {
	  none()
	}


  override Instruction getFirstInstruction() {
    result = getChild(0).getFirstInstruction()
  }

  override Instruction getInstructionSuccessor(InstructionTag tag, EdgeKind kind) {
    none()
  }

	override Instruction getInstructionOperand(InstructionTag tag, OperandTag operandTag) {
    none()
	}

	override Type getInstructionOperandType(InstructionTag tag, TypedOperandTag operandTag) {
	  none()
	}

  /**
   * Gets the `TranslatedFunction` containing this expression.
   */
  final TranslatedFunction getEnclosingFunction() {
    result = getTranslatedFunction(expr.getEnclosingFunction())
  }

  /**
   * Gets the `Function` containing this expression.
   */
  override Function getFunction() {
    result = expr.getEnclosingFunction()
  }
}

class TranslatedSideEffect extends TranslatedElement, TTranslatedArgumentSideEffect {
  Call call;
	Expr arg;
	int index;
	boolean write;

	TranslatedSideEffect() {
		this = TTranslatedArgumentSideEffect(call, arg, index, write)
	}

  override Locatable getAST() {
		result = arg
	}

	Expr getExpr() {
		result = arg
	}

	Call getCall() {
		result = call
	}

	int getArgumentIndex() {
		result = index
	}

	predicate isWrite() {
	  write = true
	}

  string toString() {
	  write = true and
    result = "(write side effect for " + arg.toString() + ")"
		or
	  write = false and
    result = "(read side effect for " + arg.toString() + ")"
  }

	override TranslatedElement getChild(int n) {
	  none()
	}

	override Instruction getChildSuccessor(TranslatedElement child) {
		none()
	}

	override Instruction getFirstInstruction() {
	  result = getInstruction(OnlyInstructionTag())
	}

	override predicate hasInstruction(Opcode opcode, InstructionTag tag, Type t, boolean isGLValue) {
	  (
	    isWrite() and
      hasSpecificWriteSideEffect(opcode) and
      tag = OnlyInstructionTag() and
      t = call.getTarget().getParameter(index).getType().getUnspecifiedType().(DerivedType).getBaseType() and
      isGLValue = false
    ) or
		(
		  not isWrite() and
      hasSpecificReadSideEffect(opcode) and
      tag = OnlyInstructionTag() and
      t = call.getTarget().getParameter(index).getType().getUnspecifiedType().(DerivedType).getBaseType() and
      isGLValue = false
    )
  }

  override Instruction getInstructionSuccessor(InstructionTag tag, EdgeKind kind) {
    result = getParent().getChildSuccessor(this) and
		tag = OnlyInstructionTag() and
		kind instanceof GotoEdge
  }

  override Instruction getInstructionOperand(InstructionTag tag,
    OperandTag operandTag) {
		operandTag instanceof AddressOperandTag and
		result = getTranslatedExpr(arg).getResult()
		or
		operandTag instanceof SideEffectOperandTag and
		call.getTarget().(SideEffectFunction).hasSpecificWriteSideEffect(index, _, false) and
		result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
		or
		operandTag instanceof SideEffectOperandTag and
		call.getTarget().(SideEffectFunction).hasSpecificReadSideEffect(index, _) and
		result = getEnclosingFunction().getUnmodeledDefinitionInstruction()
	}
	
	override Type getInstructionOperandType(InstructionTag tag, TypedOperandTag operandTag) {
	  result = arg.getType().getUnspecifiedType().(DerivedType).getBaseType() and
		operandTag instanceof SideEffectOperandTag
	}

  predicate hasSpecificWriteSideEffect(Opcode op) {
    exists(boolean buffer, boolean mustWrite |
      call.getTarget().(SideEffectFunction).hasSpecificWriteSideEffect(index, buffer, mustWrite) and
      (
        buffer = true and mustWrite = false and op instanceof Opcode::BufferMayWriteSideEffect or
        buffer = false and mustWrite = false and op instanceof Opcode::IndirectMayWriteSideEffect or
        buffer = true and mustWrite = true and op instanceof Opcode::BufferMustWriteSideEffect or
        buffer = false and mustWrite = true and op instanceof Opcode::IndirectMustWriteSideEffect
      )
    )
  }

  predicate hasSpecificReadSideEffect(Opcode t) {
    exists(boolean buffer |
      call.getTarget().(SideEffectFunction).hasSpecificReadSideEffect(index, buffer) and
      (
        buffer = true and t instanceof Opcode::BufferReadSideEffect or
        buffer = false and t instanceof Opcode::IndirectReadSideEffect
      )
    )
  }

	override Parameter getInstructionParameter(InstructionTag tag) {
	  result = call.getTarget().getParameter(index)
	}

	/**
   * Gets the `TranslatedFunction` containing this expression.
   */
  final TranslatedFunction getEnclosingFunction() {
    result = getTranslatedFunction(arg.getEnclosingFunction())
  }

  /**
   * Gets the `Function` containing this expression.
   */
  override Function getFunction() {
    result = arg.getEnclosingFunction()
  }
}