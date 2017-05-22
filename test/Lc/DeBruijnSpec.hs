module Lc.DeBruijnSpec where

import qualified Data.Set as Set

import Language.Lc
import Language.Lc.DeBruijn

import Lc.Arbitrary

import Safe

import Test.Hspec
import Test.QuickCheck


--------------------------------------------------------------
-- DeBruijn
--------------------------------------------------------------


dVar :: Integer -> DeBruijn
dVar = DVar . Index

dFree :: String -> DeBruijn
dFree = DVar . Free


-- I combinator: \x.x
dbId :: DeBruijn
dbId = DAbs "x" $ dVar 0

appDbId :: DeBruijn -> DeBruijn
appDbId = DApp dbId

-- K combinator(aka const): \x y.x
dbK :: DeBruijn
dbK = DAbs "x" (DAbs "y" (dVar 1))

appDbK :: DeBruijn -> DeBruijn -> DeBruijn
appDbK x = DApp (DApp dbK x)

-- S combinator: \x y z. x z (y z)
dbS :: DeBruijn
dbS =
  let xz = DApp (dVar 2) (dVar 0)
      yz = DApp (dVar 1) (dVar 0)
      body = DApp xz yz
  in DAbs "x" (DAbs "y" (DAbs "z" body))

appDbS :: DeBruijn -> DeBruijn -> DeBruijn -> DeBruijn
appDbS x y = DApp (DApp (DApp dbS x) y)


spec :: Spec
spec = parallel $
  describe "conversion back and forth between Lc and DeBruijn" $ do
    it "gives the original Lc" $
      property (\lc -> (toLc . fromLc $ lc) == lc)

    it "generates indexes between 0 and the number of Abs" $
      property prop_deBruijnIndexes

    it "converts from and to some examples Lc" $
      mapM_
        (\(lc, e) ->
          let db = fromLc lc
          in (db, toLc db) `shouldBe` (e, lc))
        [ (LcVar "x", dFree "x")
        , (LcAbs "x" (LcVar "x"), DAbs "x" (dVar 0))
        , (LcApp (LcVar "x") (LcVar "y"), DApp (dFree "x") (dFree "y"))
        , (LcAbs "x" (LcAbs "y" (LcVar "x")), DAbs "x" (DAbs "y" (dVar 1)))
        ]

    context "betaReduce" $ do
      it "correctly betaReduce I" $
          betaReduce (appDbId (dFree "a")) `shouldBe` dFree "a"

      it "correctly betaReduce K" $ do
        let got = betaReduceAll $ appDbK (dFree "a") (dFree "b")
        got `shouldBe` [DApp (DAbs "y" (dFree "a")) (dFree "b"), dFree "a"]

      it "correctly betaReduce S" $ do
        let got = betaReduceAll $ appDbS (dFree "a") (dFree "b") (dFree "c")
        let expected =
              [ DApp
                  (DApp
                     (DAbs
                        "y"
                        (DAbs
                           "z"
                           (DApp (DApp (dFree "a") (dVar 0)) (DApp (dVar 1) (dVar 0)))))
                     (dFree "b"))
                  (dFree "c")
              , DApp
                  (DAbs
                     "z"
                     (DApp (DApp (dFree "a") (dVar 0)) (DApp (dFree "b") (dVar 0))))
                  (dFree "c")
              , DApp (DApp (dFree "a") (dFree "c")) (DApp (dFree "b") (dFree "c")) ]
        got `shouldBe` expected

      it "correctly betaReduce omega" $ do
        let omega = DApp (DAbs "x" (DApp (dVar 0) (dVar 0))) (DAbs "x" (DApp (dVar 0) (dVar 0)))
        betaReduce omega `shouldBe` omega
        eval omega `shouldBe` omega

      it "correctly eval that SKK is I" $
        eval (appDbS dbK dbK (dFree "ski")) `shouldBe` dFree "ski"

    context "traversal" $
      it "returns all the vars" $ do
        vars exampleDb `shouldBe` [Free "x", Index 0, Index 1]
        freeVars exampleDb `shouldBe` ["x"]
        boundVars exampleDb `shouldBe` [0, 1]

  where
    exampleDb = DApp (DVar (Free "x")) (DAbs "y" (DApp (DVar (Index 0)) (DAbs "z" (DVar (Index 1)))))


-- min >= 0 && max <= number of Abs &&
-- the set of free vars must contain only the defined globals
prop_deBruijnIndexes :: Lc -> Gen Bool
prop_deBruijnIndexes lc = sized go
  where
    go :: Int -> Gen Bool
    go size =
      let db = fromLc lc
          allVars = vars db
          bvars = boundVars db
          ma = maximumDef 0 bvars
          mi = minimumDef 0 bvars
          frees = Set.fromList . freeVars $ db
      in return $ length allVars <= size + 1 &&
         mi >= 0 && mi <= ma && ma <= fromIntegral size &&
         Set.null (frees `Set.difference` globals)