{-# LANGUAGE GADTs, ScopedTypeVariables, TypeOperators #-}
module Semantic.Graph where

import           Analysis.Abstract.BadAddresses
import           Analysis.Abstract.BadModuleResolutions
import           Analysis.Abstract.BadSyntax
import           Analysis.Abstract.BadValues
import           Analysis.Abstract.BadVariables
import           Analysis.Abstract.Erroring
import           Analysis.Abstract.Evaluating
import           Analysis.Abstract.ImportGraph
import qualified Control.Exception as Exc
import           Data.Abstract.Address
import           Data.Abstract.Evaluatable
import           Data.Abstract.FreeVariables
import           Data.Abstract.Located
import           Data.Abstract.Module
import           Data.Abstract.Package as Package
import           Data.Abstract.Value (Value, ValueError)
import           Data.File
import           Data.Output
import           Data.Semilattice.Lower
import qualified Data.Syntax as Syntax
import           Data.Term
import           Parsing.Parser
import           Prologue hiding (MonadError (..))
import           Rendering.Renderer
import           Semantic.IO (Files)
import           Semantic.Task as Task

graph :: Members '[Distribute WrappedTask, Files, Task, Exc SomeException, Telemetry] effs
      => GraphRenderer output
      -> Project
      -> Eff effs ByteString
graph renderer project
  | SomeAnalysisParser parser prelude <- someAnalysisParser
    (Proxy :: Proxy '[ Evaluatable, Declarations1, FreeVariables1, Functor, Eq1, Ord1, Show1 ]) (projectLanguage project) = do
    parsePackage parser prelude project >>= graphImports >>= case renderer of
      JSONGraphRenderer -> pure . toOutput
      DOTGraphRenderer  -> pure . renderImportGraph

-- | Parse a list of files into a 'Package'.
parsePackage :: Members '[Distribute WrappedTask, Files, Task] effs
             => Parser term       -- ^ A parser.
             -> Maybe File        -- ^ Prelude (optional).
             -> Project           -- ^ Project to parse into a package.
             -> Eff effs (Package term)
parsePackage parser preludeFile project@Project{..} = do
  prelude <- traverse (parseModule parser Nothing) preludeFile
  p <- parseModules parser project
  trace ("project: " <> show p) $ pure (Package.fromModules n Nothing prelude (length projectEntryPoints) p)
  where
    n = name (projectName project)

    -- | Parse all files in a project into 'Module's.
    parseModules :: Members '[Distribute WrappedTask, Files, Task] effs => Parser term -> Project -> Eff effs [Module term]
    parseModules parser Project{..} = distributeFor (projectEntryPoints <> projectFiles) (WrapTask . parseModule parser (Just projectRootDir))

-- | Parse a file into a 'Module'.
parseModule :: Members '[Files, Task] effs => Parser term -> Maybe FilePath -> File -> Eff effs (Module term)
parseModule parser rootDir file = do
  blob <- readBlob file
  moduleForBlob rootDir blob <$> parse parser blob


importGraphAnalysis :: forall term syntax ann a
                    .  ( Element Syntax.Identifier syntax
                       , Show (Base term ())
                       )
                    => Evaluator (Located Precise term) term (Value (Located Precise term))
                      (  State (ImportGraph (Term (Sum syntax) ann))
                      ': Resumable (AddressError (Located Precise term) (Value (Located Precise term)))
                      ': Resumable (ResolutionError (Value (Located Precise term)))
                      ': Resumable (EvalError (Value (Located Precise term)))
                      ': State [Name]
                      ': Resumable (ValueError (Located Precise term) (Value (Located Precise term)))
                      ': Resumable (Unspecialized (Value (Located Precise term)))
                      ': Resumable (LoadError term)
                      ': EvaluatingEffects (Located Precise term) term (Value (Located Precise term))) a
                    -> (Either String (Either (SomeExc (LoadError term)) ((a, ImportGraph (Term (Sum syntax) ann)), [Name])), EvaluatingState (Located Precise term) term (Value (Located Precise term)))
importGraphAnalysis
  = evaluating
  . erroring @(LoadError term)
  . resumingBadSyntax
  . resumingBadValues
  . resumingBadVariables
  . resumingBadModuleResolutions
  . resumingBadAddresses
  . importGraphing

-- | Render the import graph for a given 'Package'.
graphImports :: ( Show ann
                , Ord ann
                , Apply Declarations1 syntax
                , Apply Evaluatable syntax
                , Apply FreeVariables1 syntax
                , Apply Functor syntax
                , Apply Ord1 syntax
                , Apply Eq1 syntax
                , Apply Show1 syntax
                , Element Syntax.Identifier syntax
                , Members '[Exc SomeException, Task] effs
                )
             => Package (Term (Sum syntax) ann)
             -> Eff effs (ImportGraph (Term (Sum syntax) ann))
graphImports package = analyze importGraphAnalysis (evaluatePackageWith _ _ package) >>= extractGraph
  where
    extractGraph result = case result of
      (Right (Right ((_, graph), _)), _) -> pure graph
      _ -> Task.throwError (toException (Exc.ErrorCall ("graphImports: import graph rendering failed " <> show result)))
