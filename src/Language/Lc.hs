-- | A simple lambda calculus
module Language.Lc
  ( Lc(..)
  , Var(..)
  , Abs(..)
  , App(..)
  , lam
  , pPrint
  , render
  ) where

import Text.PrettyPrint.HughesPJ
import Text.PrettyPrint.HughesPJClass (Pretty(..))

-- | Unicode lambda, a.k.a 0x03BB
lam :: Char
lam = '\955'

-- | variable, a.k.a reference
newtype Var = Var String deriving (Eq, Show)

-- | abstraction, a.k.a. anonymous function that takes one argument
-- and return one value
data Abs =
  Abs String
      Lc
  deriving (Eq, Show)

-- | function application, a.k.a call a lambda with an argument
data App =
  App Lc
      Lc
  deriving (Eq, Show)

-- | the AST of the vanilla untyped lambda calculus
data Lc
  = LcVar Var
  | LcAbs Abs
  | LcApp App
  deriving (Show, Eq)

instance Pretty Lc where
  -- | pretty print the AST into a human readable form
  pPrint (LcVar v) = pPrint v
  pPrint (LcAbs a) = pPrint a
  pPrint (LcApp a) = pPrint a

instance Pretty Var where
  pPrint (Var v) = text v

instance Pretty Abs where
  pPrint (Abs arg body) = char lam <> text arg <> char '.' <> pPrint body

instance Pretty App where
  pPrint (App fn arg) = let parensIfNotVar p = maybeParens (not $ isVar p) (pPrint p)
    in parensIfNotVar fn <+> parensIfNotVar arg

isVar :: Lc -> Bool
isVar (LcVar _) = True
isVar _ = False