
IR-based range analysis
-----------------------
The IR-based range analysis library (defined in ``RangeAnalysis.qll``) provides classes and predicates for determining both constant and relative upper and lower bounds on expressions.

The QL interface
~~~~~~~~~~~~~~~~
The ``Bound`` class represents values that can be bounded against. A ``Bound`` is either a ``ValueNumberBound``, which represents a set of ``Instructions`` which will be equal at runtime, or the ``ZeroBound``. For more information about the ``ValueNumber`` library, see :doc:`Using value numbering for C and C++ <value-numbering>`

The ``Reason`` class represents comparisons that may be the reason that a value is bounded. A ``Reason`` is either a ``CondReason``, representing a particular conditional expression that produces a bound, or ``NoReason``, meaning that the value is bounded because it is derived from the bounding value.

The ``boundedInstruction(Instruction i, Bound b, int delta, boolean upper, Reason reason)`` predicate holds if ``upper == true`` and ``i <= b + delta`` must hold, or if ``upper == false`` and ``i >= b + delta`` must hold. Similarly, the ``boundedOperand(Operand op, Bound b, int delta, boolean upper, Reason reason)`` predicate holds if ``upper == true`` and ``op <= b + delta`` must hold or if ``upper == false`` and ``op >= b + delta`` must hold.

Example
~~~~~~~
This query uses the ``boundedOperand`` predicate to recognize off-by-one errors within a function.

.. code-block:: ql

    from
      CallInstruction ci, PointerAddInstruction pai, ValueNumberBound b, int delta
    where
      // the number of elements allocated, plus some delta, is an upper bound on the size operand of a pointer addition
      boundedOperand(pai.getRightOperand(), b, delta, true, _) and
      b.(ValueNumberBound).getAnInstruction() = ci.getPositionalArgument(0) and

      // a call to calloc flows to the pointer operand of a pointer addition
      ci.getStaticCallTarget().hasName("calloc") and
      DataFlow::localFlow(ci, pai.getLeftOperand().getDefinitionInstruction()) and

      // the pointer addition is dereferenced
      li.getSourceAddress() = pai and

      // the bound is not strict, allowing a buffer overrun
      delta >= 0

    select pai.getAST(),
      "Access to $@ is improperly bounded, and may overrun by " + delta.toString() + "elements",
      ci.getAST(), ci.getAST().toString()
