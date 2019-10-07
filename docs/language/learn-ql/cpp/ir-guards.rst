Using the guards library in C and C++
=====================================

Overview
--------
The guards library (defined in ``semmle.code.cpp.controlflow.irguards``) provides a class ``IRGuardCondition`` representing boolean values which are used to make control flow decisions.

The ``ensuresEq`` and ``ensuresLt`` predicates
----------------------------------------------
The ``ensuresLt`` and ``ensuresEq`` predicates are the main way of determining what, if any, guarantees the ``IRGuardCondition`` provides for a given basic block.

``ensuresEq(left, right, k, block, areEqual)`` holds if ``left == right + k`` must be ``areEqual`` for ``block`` to be executed. If ``areEqual = false`` then this implies ``left != right + k`` must be true for ``block`` to be executed.

``ensuresLt(left, right, k, block, isLessThan)`` holds if ``left < right + k`` must be ``isLessThan`` for ``block`` to be executed. If ``isLessThan = false`` then this implies ``left >= right + k`` must be true for ``block`` to be executed.

.. TODO: examples for these predicates (none for others?)

The ``ensuresEqEdge`` and ``ensuresLtEdge`` predicates
------------------------------------------------------
These predicates determine what guarantees the ``IRGuardCondition`` provides as a given edge is taken. They are primarily useful for handling the following situation:

.. code-block:: c

    void init (int *p, int x) {
      if(p == 0) {
        p = malloc(sizeof(int));
      }
      *p = x;
    }

In this case, the guard ``p == 0`` does not control the basic block containing ``*p = x;``, so ``ensuresEq`` will not hold. However, an  analysis could use ``ensuresEqEdge`` to determine that ``p`` is not ``0`` along the edge where ``p == 0`` evaluates to false.

The ``comparesEq`` and ``comparesLt`` predicates
------------------------------------------------
The ``comparesEq`` and ``comparesLt`` predicates help determine if the ``IRGuardCondition`` evaluates to true.

``comparesEq(left, right, k, areEqual, testIsTrue)`` holds if ``left == right + k`` evaluates to ``areEqual`` if the expression evaluates to ``testIsTrue``.

``comparesLt(left, right, k, isLessThan, testIsTrue)`` holds if ``left < right + k`` evaluates to ``isLessThan`` if the expression evaluates to ``testIsTrue``.

The ``controls`` and ``controlsEdge`` predicates
------------------------------------------------
The ``controls`` and ``controlsEdge`` predicates help determine which blocks are only run when the ``IRGuardCondition`` evaluates a certain way.

``controls(block, testIsTrue)`` only holds if ``block`` is only entered if the value of this condition is ``testIsTrue``.

``controlsEdge(pred, succ, testIsTrue)`` only holds if the edge from ``pred`` to ``succ`` can only be taken if the value of this condition is ``testIsTrue``.
