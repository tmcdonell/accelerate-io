{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}
-- |
-- Module      : Test.Vector.Storable
-- Copyright   : [2017] Trevor L. McDonell
-- License     : BSD3
--
-- Maintainer  : Trevor L. McDonell <tmcdonell@cse.unsw.edu.au>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--

module Test.Vector.Storable
  where

import Test.Util
import Test.Tasty
import Test.Tasty.Hedgehog

import Data.Array.Accelerate                                        ( Array, Shape, Elt, DIM0, DIM1, DIM2, Z(..), (:.)(..) )
import Data.Array.Accelerate.Array.Sugar                            ( rank, EltRepr )
import Data.Array.Accelerate.IO.Data.Vector.Storable                as A
import qualified Data.Array.Accelerate.Hedgehog.Gen.Array           as Gen
import qualified Data.Array.Accelerate.Hedgehog.Gen.Shape           as Gen

import Data.Vector.Storable                                         as S

import Hedgehog
import qualified Hedgehog.Gen                                       as Gen
import qualified Hedgehog.Range                                     as Range

import Data.Proxy
import Data.Functor.Identity
import Text.Printf


storable :: Storable e => Int -> Gen e -> Gen (S.Vector e)
storable n gen =
  S.fromListN n <$> Gen.list (Range.singleton n) gen

test_s2a
    :: forall e. (Storable e, Elt e, Eq e, Vectors (EltRepr e) ~ Vector e)
    => Gen e
    -> Property
test_s2a e =
  property $ do
    sh@(Z :. n) <- forAll shape
    svec        <- forAll (storable n e)
    --
    tripping svec (A.fromVectors sh :: Vector e -> Array DIM1 e) (Identity . A.toVectors)

test_s2a_t2
    :: forall a b. ( Storable a, Elt a, Eq a, Vectors (EltRepr a) ~ Vector a
                   , Storable b, Elt b, Eq b, Vectors (EltRepr b) ~ Vector b
                   )
    => Gen a
    -> Gen b
    -> Property
test_s2a_t2 a b =
  property $ do
    sh@(Z :. n) <- forAll shape
    sa          <- forAll (storable n a)
    sb          <- forAll (storable n b)
    let svecs    = (((), sa), sb)
    --
    tripping svecs (A.fromVectors sh :: Vectors (EltRepr (a,b)) -> Array DIM1 (a,b)) (Identity . A.toVectors)


test_a2s
    :: forall sh e. (Gen.Shape sh, Shape sh, Elt e, Eq sh, Eq e, Show (Vectors (EltRepr e)))
    => Proxy sh
    -> Gen e
    -> Property
test_a2s _ e =
  property $ do
    sh  <- forAll (shape :: Gen sh)
    arr <- forAll (Gen.array sh e)
    --
    tripping arr A.toVectors (Identity . A.fromVectors sh)


test_a2s_dim
    :: forall sh. (Gen.Shape sh, Shape sh, Eq sh)
    => Proxy sh
    -> TestTree
test_a2s_dim dim =
  testGroup (printf "DIM%d" (rank (undefined::sh)))
    [ testProperty "Int"                    $ test_a2s dim int
    , testProperty "Int8"                   $ test_a2s dim i8
    , testProperty "Int16"                  $ test_a2s dim i16
    , testProperty "Int32"                  $ test_a2s dim i32
    , testProperty "Int64"                  $ test_a2s dim i64
    , testProperty "Word"                   $ test_a2s dim word
    , testProperty "Word8"                  $ test_a2s dim w8
    , testProperty "Word16"                 $ test_a2s dim w16
    , testProperty "Word32"                 $ test_a2s dim w32
    , testProperty "Word64"                 $ test_a2s dim w64
    , testProperty "Float"                  $ test_a2s dim f32
    , testProperty "Double"                 $ test_a2s dim f64
    , testProperty "Complex Float"          $ test_a2s dim (complex f32)
    , testProperty "(Double, Int16)"        $ test_a2s dim ((,) <$> f64 <*> i16)
    , testProperty "(Float, (Double,Int))"  $ test_a2s dim ((,) <$> f32 <*> ((,) <$> f64 <*> int))
    ]

test_vector_storable :: TestTree
test_vector_storable =
  testGroup "Data.Vector.Storable"
    [ testGroup "storable->accelerate"
      [ testProperty "Int"         $ test_s2a int
      , testProperty "Int8"        $ test_s2a i8
      , testProperty "Int16"       $ test_s2a i16
      , testProperty "Int32"       $ test_s2a i32
      , testProperty "Int64"       $ test_s2a i64
      , testProperty "Word"        $ test_s2a word
      , testProperty "Word8"       $ test_s2a w8
      , testProperty "Word16"      $ test_s2a w16
      , testProperty "Word32"      $ test_s2a w32
      , testProperty "Word64"      $ test_s2a w64
      , testProperty "Float"       $ test_s2a f32
      , testProperty "Double"      $ test_s2a f64
      , testProperty "(Int,Float)" $ test_s2a_t2 int f32
      , testProperty "(Int8,Word)" $ test_s2a_t2 i8 word
      ]
    , testGroup"accelerate->storable"
      [ test_a2s_dim (Proxy::Proxy DIM0)
      , test_a2s_dim (Proxy::Proxy DIM1)
      , test_a2s_dim (Proxy::Proxy DIM2)
      ]
    ]
