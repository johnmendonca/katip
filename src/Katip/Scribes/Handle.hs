{-# LANGUAGE RecordWildCards #-}

module Katip.Scribes.Handle
    ( mkHandleScribe
    ) where

-------------------------------------------------------------------------------
import           Blaze.ByteString.Builder
import           Blaze.ByteString.Builder.Char.Utf8
import           Control.Lens
import           Data.Aeson                         (ToJSON (..))
import           Data.Aeson.Lens
import qualified Data.ByteString.Char8              as B
import           Data.Maybe
import           Data.Monoid
import           Data.Text                          (Text)
import           Data.Time
import           System.IO
import           System.IO.Unsafe                   (unsafePerformIO)
import           System.Locale
-------------------------------------------------------------------------------
import           Katip.Core
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
brackets :: Builder -> Builder
brackets m = fromByteString "[" <> m <> fromByteString "]"


-------------------------------------------------------------------------------
getKeys :: LogContext s => s -> [Builder]
getKeys a = flip mapMaybe (importantKeys a) $ \ k ->
    a' ^? key k . _Primitive . to renderPrim
  where
    a' = toJSON a


-------------------------------------------------------------------------------
renderPrim (StringPrim t) = fromText t
renderPrim (NumberPrim s) = fromString (show s)
renderPrim (BoolPrim b) = fromString (show b)
renderPrim NullPrim = fromByteString "null"


-------------------------------------------------------------------------------
mkHandleScribe :: Handle -> Severity -> IO Scribe
mkHandleScribe h sev = do
    hSetBuffering h LineBuffering
    return $ Scribe $ \ Item{..} -> do
      let nowStr = fromString $ formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" itemTime
          ks = map brackets $ getKeys itemPayload
          msg = brackets nowStr <>
                brackets (fromText (renderSeverity itemSeverity)) <>
                brackets (fromString itemHost) <>
                brackets (fromString (show itemThread)) <>
                mconcat ks <>
                fromText " " <> fromText itemMessage
      if itemSeverity >= sev
        then B.putStrLn $ toByteString msg
        else return ()



-------------------------------------------------------------------------------
-- | An implicit environment to enable logging directly ouf of the IO monad.
_ioLogEnv :: LogEnv
_ioLogEnv = unsafePerformIO $ do
    le <- initLogEnv "io" "io"
    lh <- mkHandleScribe stdout Debug
    return $ registerHandler "stdout" lh le
{-# NOINLINE _ioLogEnv #-}


-------------------------------------------------------------------------------
-- | A default IO instance to make prototype development easy. User
-- your own 'Monad' for production.
instance Katip IO where getLogEnv = return _ioLogEnv
