{-# LANGUAGE DeriveAnyClass, MultiParamTypeClasses, ScopedTypeVariables, UndecidableInstances, ViewPatterns #-}
module Data.Syntax.Statement where

import qualified Data.Abstract.Environment as Env
import Data.Abstract.Evaluatable
import Data.ByteString.Char8 (unpack)
import Data.JSON.Fields
import Diffing.Algorithm
import Prelude
import Prologue

-- | Conditional. This must have an else block, which can be filled with some default value when omitted in the source, e.g. 'pure ()' for C-style if-without-else or 'pure Nothing' for Ruby-style, in both cases assuming some appropriate Applicative context into which the If will be lifted.
data If a = If { ifCondition :: !a, ifThenBody :: !a, ifElseBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 If where liftEq = genericLiftEq
instance Ord1 If where liftCompare = genericLiftCompare
instance Show1 If where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 If

instance Evaluatable If where
  eval (If cond if' else') = do
    bool <- subtermValue cond
    Rval <$> ifthenelse bool (subtermValue if') (subtermValue else')

-- | Else statement. The else condition is any term, that upon successful completion, continues evaluation to the elseBody, e.g. `for ... else` in Python.
data Else a = Else { elseCondition :: !a, elseBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Else where liftEq = genericLiftEq
instance Ord1 Else where liftCompare = genericLiftCompare
instance Show1 Else where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Else

-- TODO: Implement Eval instance for Else
instance Evaluatable Else

-- TODO: Alternative definition would flatten if/else if/else chains: data If a = If ![(a, a)] !(Maybe a)

-- | Goto statement (e.g. `goto a` in Go).
newtype Goto a = Goto { gotoLocation :: a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Goto where liftEq = genericLiftEq
instance Ord1 Goto where liftCompare = genericLiftCompare
instance Show1 Goto where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Goto

-- TODO: Implement Eval instance for Goto
instance Evaluatable Goto


-- | A pattern-matching or computed jump control-flow statement, like 'switch' in C or JavaScript, or 'case' in Ruby or Haskell.
data Match a = Match { matchSubject :: !a, matchPatterns :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Match where liftEq = genericLiftEq
instance Ord1 Match where liftCompare = genericLiftCompare
instance Show1 Match where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Match

-- TODO: Implement Eval instance for Match
instance Evaluatable Match


-- | A pattern in a pattern-matching or computed jump control-flow statement, like 'case' in C or JavaScript, 'when' in Ruby, or the left-hand side of '->' in the body of Haskell 'case' expressions.
data Pattern a = Pattern { _pattern :: !a, patternBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Pattern where liftEq = genericLiftEq
instance Ord1 Pattern where liftCompare = genericLiftCompare
instance Show1 Pattern where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Pattern

-- TODO: Implement Eval instance for Pattern
instance Evaluatable Pattern


-- | A let statement or local binding, like 'a as b' or 'let a = b'.
data Let a  = Let { letVariable :: !a, letValue :: !a, letBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Let where liftEq = genericLiftEq
instance Ord1 Let where liftCompare = genericLiftCompare
instance Show1 Let where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Let

instance Evaluatable Let where
  eval Let{..} = do
    name <- either (throwEvalError . FreeVariablesError) pure (freeVariable $ subterm letVariable)
    addr <- snd <$> letrec name (subtermValue letValue)
    Rval <$> localEnv (Env.insert name addr) (subtermValue letBody)


-- Assignment

-- | Assignment to a variable or other lvalue.
data Assignment a = Assignment { assignmentContext :: ![a], assignmentTarget :: !a, assignmentValue :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Assignment where liftEq = genericLiftEq
instance Ord1 Assignment where liftCompare = genericLiftCompare
instance Show1 Assignment where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Assignment

instance Evaluatable Assignment where
  eval Assignment{..} = do
    lhs <- subtermRef assignmentTarget
    rhs <- subtermValue assignmentValue

    case lhs of
      LvalLocal nam -> do
        addr <- lookupOrAlloc nam
        assign addr rhs
        modifyEnv (Env.insert nam addr)
      LvalMember _ _ ->
        -- we don't yet support mutable object properties:
        pure ()
      Rval _ ->
        -- the left hand side of the assignment expression is invalid:
        pure ()

    pure (Rval rhs)

-- | Post increment operator (e.g. 1++ in Go, or i++ in C).
newtype PostIncrement a = PostIncrement a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 PostIncrement where liftEq = genericLiftEq
instance Ord1 PostIncrement where liftCompare = genericLiftCompare
instance Show1 PostIncrement where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 PostIncrement

-- TODO: Implement Eval instance for PostIncrement
instance Evaluatable PostIncrement


-- | Post decrement operator (e.g. 1-- in Go, or i-- in C).
newtype PostDecrement a = PostDecrement a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 PostDecrement where liftEq = genericLiftEq
instance Ord1 PostDecrement where liftCompare = genericLiftCompare
instance Show1 PostDecrement where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 PostDecrement

-- TODO: Implement Eval instance for PostDecrement
instance Evaluatable PostDecrement


-- Returns

newtype Return a = Return a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Return where liftEq = genericLiftEq
instance Ord1 Return where liftCompare = genericLiftCompare
instance Show1 Return where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Return

instance Evaluatable Return where
  eval (Return x) = Rval <$> (subtermValue x >>= earlyReturn)

newtype Yield a = Yield a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Yield where liftEq = genericLiftEq
instance Ord1 Yield where liftCompare = genericLiftCompare
instance Show1 Yield where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Yield

-- TODO: Implement Eval instance for Yield
instance Evaluatable Yield


newtype Break a = Break a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Break where liftEq = genericLiftEq
instance Ord1 Break where liftCompare = genericLiftCompare
instance Show1 Break where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Break

instance Evaluatable Break where
  eval (Break x) = Rval <$> (subtermValue x >>= throwBreak)

newtype Continue a = Continue a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Continue where liftEq = genericLiftEq
instance Ord1 Continue where liftCompare = genericLiftCompare
instance Show1 Continue where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Continue

instance Evaluatable Continue where
  eval (Continue a) = Rval <$> (subtermValue a >>= throwContinue)

newtype Retry a = Retry a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Retry where liftEq = genericLiftEq
instance Ord1 Retry where liftCompare = genericLiftCompare
instance Show1 Retry where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Retry

-- TODO: Implement Eval instance for Retry
instance Evaluatable Retry


newtype NoOp a = NoOp a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 NoOp where liftEq = genericLiftEq
instance Ord1 NoOp where liftCompare = genericLiftCompare
instance Show1 NoOp where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 NoOp

instance Evaluatable NoOp where
  eval _ = pure (Rval unit)

-- Loops

data For a = For { forBefore :: !a, forCondition :: !a, forStep :: !a, forBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 For where liftEq = genericLiftEq
instance Ord1 For where liftCompare = genericLiftCompare
instance Show1 For where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 For

instance Evaluatable For where
  eval (fmap subtermValue -> For before cond step body) = Rval <$> forLoop before cond step body


data ForEach a = ForEach { forEachBinding :: !a, forEachSubject :: !a, forEachBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 ForEach where liftEq = genericLiftEq
instance Ord1 ForEach where liftCompare = genericLiftCompare
instance Show1 ForEach where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 ForEach

-- TODO: Implement Eval instance for ForEach
instance Evaluatable ForEach


data While a = While { whileCondition :: !a, whileBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 While where liftEq = genericLiftEq
instance Ord1 While where liftCompare = genericLiftCompare
instance Show1 While where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 While

instance Evaluatable While where
  eval While{..} = Rval <$> while (subtermValue whileCondition) (subtermValue whileBody)

data DoWhile a = DoWhile { doWhileCondition :: !a, doWhileBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 DoWhile where liftEq = genericLiftEq
instance Ord1 DoWhile where liftCompare = genericLiftCompare
instance Show1 DoWhile where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 DoWhile

instance Evaluatable DoWhile where
  eval DoWhile{..} = Rval <$> doWhile (subtermValue doWhileBody) (subtermValue doWhileCondition)

-- Exception handling

newtype Throw a = Throw a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Throw where liftEq = genericLiftEq
instance Ord1 Throw where liftCompare = genericLiftCompare
instance Show1 Throw where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Throw

-- TODO: Implement Eval instance for Throw
instance Evaluatable Throw


data Try a = Try { tryBody :: !a, tryCatch :: ![a] }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Try where liftEq = genericLiftEq
instance Ord1 Try where liftCompare = genericLiftCompare
instance Show1 Try where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Try

-- TODO: Implement Eval instance for Try
instance Evaluatable Try


data Catch a = Catch { catchException :: !a, catchBody :: !a }
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Catch where liftEq = genericLiftEq
instance Ord1 Catch where liftCompare = genericLiftCompare
instance Show1 Catch where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Catch

-- TODO: Implement Eval instance for Catch
instance Evaluatable Catch


newtype Finally a = Finally a
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Finally where liftEq = genericLiftEq
instance Ord1 Finally where liftCompare = genericLiftCompare
instance Show1 Finally where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Finally

-- TODO: Implement Eval instance for Finally
instance Evaluatable Finally


-- Scoping

-- | ScopeEntry (e.g. `BEGIN {}` block in Ruby or Perl).
newtype ScopeEntry a = ScopeEntry [a]
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 ScopeEntry where liftEq = genericLiftEq
instance Ord1 ScopeEntry where liftCompare = genericLiftCompare
instance Show1 ScopeEntry where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 ScopeEntry

-- TODO: Implement Eval instance for ScopeEntry
instance Evaluatable ScopeEntry


-- | ScopeExit (e.g. `END {}` block in Ruby or Perl).
newtype ScopeExit a = ScopeExit [a]
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 ScopeExit where liftEq = genericLiftEq
instance Ord1 ScopeExit where liftCompare = genericLiftCompare
instance Show1 ScopeExit where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 ScopeExit

-- TODO: Implement Eval instance for ScopeExit
instance Evaluatable ScopeExit

-- | HashBang line (e.g. `#!/usr/bin/env node`)
newtype HashBang a = HashBang ByteString
  deriving (Diffable, Eq, Foldable, Functor, GAlign, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 HashBang where liftEq = genericLiftEq
instance Ord1 HashBang where liftCompare = genericLiftCompare
instance Show1 HashBang where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 HashBang where
  toJSONFields1 (HashBang f) = noChildren [ "contents" .= unpack f ]

-- TODO: Implement Eval instance for HashBang
instance Evaluatable HashBang
