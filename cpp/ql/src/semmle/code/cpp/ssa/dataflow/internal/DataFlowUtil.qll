/**
 * Provides C++-specific definitions for use in the data flow library.
 */
import cpp
import semmle.code.cpp.ssa.AliasedSSAIR

/**
 * A node in a data flow graph.
 *
 * A node can be either an expression, a parameter, or an uninitialized local
 * variable. Such nodes are created with `DataFlow::exprNode`,
 * `DataFlow::parameterNode`, and `DataFlow::uninitializedNode` respectively.
*/
class Node extends Instruction {
  /**
   * INTERNAL: Do not use. Alternative name for `getFunction`.
   */
  Function getEnclosingCallable() {
    result = this.getFunction()
  }

  /** Gets the type of this node. */
  Type getType() {
    result = this.asExpr().getType()
    or
    result = this.getAST().(Variable).getType()
  }

  /** Gets the expression corresponding to this node, if any. */
  Expr asExpr() { result = this.getAST() }

  /** Gets the parameter corresponding to this node, if any. */
  Parameter asParameter() { result = this.(ParameterNode).getParameter() }

  /**
   * Gets the uninitialized local variable corresponding to this node, if
   * any.
   */
  LocalVariable asUninitialized() {
    result = this.(UninitializedNode).getLocalVariable()
  }
}

/**
 * An expression, viewed as a node in a data flow graph.
 */
class ExprNode extends Node {
  ExprNode() { getAST() instanceof Expr }
  Expr getExpr() { result = getAST() }
}

/**
 * The value of a parameter at function entry, viewed as a node in a data
 * flow graph.
 */
class ParameterNode extends Node, InitializeParameterInstruction {
  /**
   * Holds if this node is the parameter of `c` at the specified (zero-based)
   * position. The implicit `this` parameter is considered to have index `-1`.
   */
  predicate isParameterOf(Function f, int i) {
    f.getParameter(i) = getParameter()
  }
}

/**
 * The value of an uninitialized local variable, viewed as a node in a data
 * flow graph.
 */
class UninitializedNode extends Node, UninitializedInstruction {
  /** Gets the uninitialized local variable corresponding to this node. */
  LocalVariable getLocalVariable() { result = this.getAST().(VariableDeclarationEntry).getDeclaration()}
}

/**
 * A node associated with an object after an operation that might have
 * changed its state.
 *
 * This can be either the argument to a callable after the callable returns
 * (which might have mutated the argument), or the qualifier of a field after
 * an update to the field.
 *
 * Nodes corresponding to AST elements, for example `ExprNode`, usually refer
 * to the value before the update with the exception of `ClassInstanceExpr`,
 * which represents the value after the constructor has run.
 */
abstract class PostUpdateNode extends Node {
  /**
   * Gets the node before the state update.
   */
  abstract Node getPreUpdateNode();
}

class StoreDestinationAsPostUpdateNode extends PostUpdateNode {
  StoreInstruction si;
  StoreDestinationAsPostUpdateNode() {
    this = si.getDestinationAddress()
  }
  
  override Node getPreUpdateNode() {
    result = si.getDestinationAddress()
  }
}

/**
 * Gets the `Node` corresponding to `e`.
 */
ExprNode exprNode(Expr e) { result.getExpr() = e }

/**
 * Gets the `Node` corresponding to the value of `p` at function entry.
 */
ParameterNode parameterNode(Parameter p) { result.getParameter() = p }

/**
 * Gets the `Node` corresponding to the value of an uninitialized local
 * variable `v`.
 */
UninitializedNode uninitializedNode(LocalVariable v) {
  result.getLocalVariable() = v
}

/**
 * Holds if data flows from `nodeFrom` to `nodeTo` in exactly one local
 * (intra-procedural) step.
 */
predicate localFlowStep(Node nodeFrom, Node nodeTo) {
  nodeTo.(CopyInstruction).getSourceValue() = nodeFrom or
  nodeTo.(PhiInstruction).getAnOperand() = nodeFrom
}

/**
 * Holds if data flows from `source` to `sink` in zero or more local
 * (intra-procedural) steps.
 */
predicate localFlow(Node source, Node sink) {
  localFlowStep*(source, sink)
}
