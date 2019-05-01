import cpp
import semmle.code.cpp.ir.dataflow.DataFlow
import semmle.code.cpp.models.interfaces.Alias
import semmle.code.cpp.models.interfaces.SideEffect


/** Common data flow configuration to be used by tests. */
class TestAllocationConfig extends DataFlow::Configuration {
  TestAllocationConfig() {
    this = "TestAllocationConfig"
  }

  override predicate isSource(DataFlow::Node source) {
    source.asExpr().(FunctionCall).getTarget().getName() = "source"
    or
    source.asParameter().getName().matches("source%")
    or
    source.(DataFlow::DefinitionByReferenceNode).getParameter().getName().matches("ref_source%")
    or
    // Track uninitialized variables
    exists(source.asUninitialized())
  }

  override predicate isSink(DataFlow::Node sink) {
    exists(FunctionCall call |
      call.getTarget().getName() = "sink" and
      sink.asExpr() = call.getAnArgument()
    )
  }

  override predicate isBarrier(DataFlow::Node barrier) {
    barrier.asExpr().(VariableAccess).getTarget().hasName("barrier")
  }
}

class RefSourceFunction extends SideEffectFunction, AliasFunction {
  Parameter parameter;

	RefSourceFunction() {
	  parameter = getParameter(_) and
		parameter.getName().matches("ref_source%")
	}

  override predicate neverReadsMemory() {
		any()
	}

  override predicate neverWritesMemory() {
		any()
	}

  override predicate hasSpecificWriteSideEffect(ParameterIndex i, boolean buffer, boolean mustWrite) {
    i = parameter.getIndex() and
		buffer = false and
		mustWrite = true
  }

  predicate parameterNeverEscapes(int index) {
		exists(getParameter(index))
	}

	predicate parameterEscapesOnlyViaReturn(int index) {
		none()
	}

	predicate parameterIsAlwaysReturned(int index) {
		none()
	}
}