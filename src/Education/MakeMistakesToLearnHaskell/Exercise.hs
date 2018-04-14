{-# OPTIONS_GHC -Wno-unused-imports #-}

module Education.MakeMistakesToLearnHaskell.Exercise
  ( Exercise(verify)
  , ExerciseId
  , Result(..)
  , Details
  , loadHeaders
  , loadDescriptionById
  , loadExampleSolution
  , loadLastShown
  , saveLastShownId
  , unsafeGetById
  ) where


#include <imports/external.hs>

import qualified Paths_makeMistakesToLearnHaskell

import           Education.MakeMistakesToLearnHaskell.Diagnosis
import           Education.MakeMistakesToLearnHaskell.Env
import qualified Education.MakeMistakesToLearnHaskell.Evaluator.RunHaskell as RunHaskell
import           Education.MakeMistakesToLearnHaskell.Evaluator.Util
import           Education.MakeMistakesToLearnHaskell.Exercise.Record
import           Education.MakeMistakesToLearnHaskell.Exercise.Types
import           Education.MakeMistakesToLearnHaskell.Error


exercises :: Vector Exercise
exercises = Vector.fromList [exercise1]
  where
    exercise1 =
      Exercise "1" $ \e prgFile -> do
        result <- runHaskell e e prgFile
        case result of
            Right (outB, errB) -> do
              let right = "Hello, world!\n"
                  out = canonicalizeOutput outB
              logDebug e $ "Right: " <> errB
              let err = TextEncoding.decodeUtf8 errB
                  eMsg =
                    if Text.null err
                      then ""
                      else
                        Text.unlines
                          ["Found error message printed on stderr:", err]
                  msg = Text.unlines
                        [ Text.replicate 80 "="
                        , "Your program's output: " <> Text.pack (show out)
                        , "      Expected output: " <> Text.pack (show right)
                        ]
              return $
                if out == right && Text.null eMsg
                  then Success $ "Nice output!\n\n" <> msg
                  else Fail $ "Wrong output!\n\n" <> msg
            Left err ->
              case err of
                  RunHaskell.RunHaskellNotFound ->
                    return $ Error "runhaskell command is not available.\nInstall stack or Haskell Platform."
                  RunHaskell.RunHaskellFailure _ msg -> do
                    logDebug e $ "RunHaskellFailure: " <> msg
                    code <- Text.readFile prgFile
                    return $ Fail $ appendDiagnosis code msg


loadHeaders :: IO [Text]
loadHeaders = mapM loadHeader $ Vector.toList exercises
  where
    loadHeader ex = extractHeader ex =<< loadDescription ex
    extractHeader ex desc =
      dieWhenNothing ("The description of exercise '" ++ exerciseName ex ++ "' is empty!")
        $ cutHash <$> headMay (Text.lines desc)
    cutHash h =
      Text.strip $ fromMaybe h $ Text.stripPrefix "# " h


loadDescription :: Exercise -> IO Text
loadDescription = loadWithExtension ".md"


loadExampleSolution :: Exercise -> IO Text
loadExampleSolution = loadWithExtension ".hs"


loadWithExtension :: String -> Exercise -> IO Text
loadWithExtension ext ex =
  Paths_makeMistakesToLearnHaskell.getDataFileName ("assets/" ++ exerciseName ex ++ ext)
    >>= Text.readFile


loadDescriptionById :: ExerciseId -> IO (Maybe Text)
loadDescriptionById n = MaybeT.runMaybeT $ do
  ex <- Error.hoistMaybe $ getById n
  liftIO $ loadDescription ex


-- Handle error internally.
-- Because lastShownId is usually saved internally.
loadLastShown :: Env -> IO Exercise
loadLastShown e =
  loadLastShownId e >>=
    dieWhenNothing "Assertion failure: Invalid lastShownId saved! " . getById


getById :: ExerciseId -> Maybe Exercise
getById n = exercises !? (n - 1)


unsafeGetById :: ExerciseId -> Exercise
unsafeGetById n = exercises ! (n - 1)