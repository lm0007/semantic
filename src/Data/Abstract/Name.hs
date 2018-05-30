module Data.Abstract.Name
( Name
-- * Constructors
, name
, nameI
, unName
) where

import qualified Data.Char as Char
import           Data.Text (Text)
import qualified Data.Text as Text
import           Data.String
import           Prologue

-- | The type of variable names.
data Name
  = Name Text
  | I Int
  deriving (Eq, Ord)

-- | Construct a 'Name' from a 'ByteString'.
name :: Text -> Name
name = Name

-- | Construct a 'Name' from an 'Int'. This is suitable for automatic generation, e.g. using a Fresh effect, but should not be used for human-generated names.
nameI :: Int -> Name
nameI = I

-- | Extract a human-readable 'Text' from a 'Name'.
unName :: Name -> Text
unName (Name name) = name
unName (I i)       = Text.pack $ '_' : (alphabet !! a) : replicate n 'ʹ'
  where alphabet = ['a'..'z']
        (n, a) = i `divMod` length alphabet

instance IsString Name where
  fromString = Name . Text.pack

-- $
-- >>> I 0
-- "_a"
-- >>> I 26
-- "_aʹ"
instance Show Name where
  showsPrec _ = prettyShowString . Text.unpack . unName
    where prettyShowString str = showChar '"' . foldr ((.) . prettyChar) id str . showChar '"'
          prettyChar c
            | c `elem` ['\\', '\"'] = Char.showLitChar c
            | Char.isPrint c        = showChar c
            | otherwise             = Char.showLitChar c

instance Hashable Name where
  hashWithSalt salt (Name name) = hashWithSalt salt name
  hashWithSalt salt (I i)       = salt `hashWithSalt` (1 :: Int) `hashWithSalt` i
