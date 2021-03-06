{-# LANGUAGE CPP                 #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Raw constants which we want to have in 'core'. They have simpler
-- types than constants from 'Typed' module. It's done to avoid cyclic
-- dependencies. To be more precise, this module doesn't import
-- 'Pos.Core.Types', while 'Typed' module does.

module Pos.Core.Constants.Raw
       (
       -- * Non-configurable constants
         sharedSeedLength
       , genesisHash

       -- * The config structure
       , CoreConstants(..)
       , coreConstants

       -- * Constants
       , epochSlots
       , blkSecurityParam
       , slotSecurityParam
       , isDevelopment
       , protocolMagic
       , staticSysStartRaw
       , genesisKeysN
       , memPoolLimitRatio

       ) where

import           Universum

import           Data.Aeson                 (FromJSON (..), genericParseJSON)
import           Data.Tagged                (Tagged (..))
import           Data.Time.Units            (Microsecond)
import           Serokell.Aeson.Options     (defaultOptions)
import           Serokell.Data.Memory.Units (Byte)
import           Serokell.Util              (sec)

import           Pos.Crypto.Hashing         (Hash, unsafeHash)
import           Pos.Util.Config            (IsConfig (..), configParser,
                                             parseFromCslConfig)
import           Pos.Util.Util              ()

----------------------------------------------------------------------------
-- Constants which are not configurable
----------------------------------------------------------------------------

-- | Length of shared seed.
sharedSeedLength :: Integral a => a
sharedSeedLength = 32

-- | Predefined 'Hash' of the parent of the 0-th genesis block (which
-- is the only block without a real parent).
genesisHash :: Hash a
genesisHash = unsafeHash @Text "patak"
{-# INLINE genesisHash #-}

----------------------------------------------------------------------------
-- Config itself
----------------------------------------------------------------------------

data CoreConstants = CoreConstants
    {
      -- | Security parameter from paper
      ccK                            :: !Int
    , -- | Magic constant for separating real/testnet
      ccProtocolMagic                :: !Int32
    , -- | Start time of network (in @Production@ running mode). If set to
      -- zero, then running time is 2 minutes after build.
      ccProductionNetworkStartTime   :: !Int
    , -- | Number of pre-generated keys
      ccGenesisN                     :: !Int
      -- | Size of mem pool will be limited by this value muliplied by block
      -- size limit.
    , ccMemPoolLimitRatio            :: !Word

       ----------------------------------------------------------------------------
       -- Genesis block version data
       ----------------------------------------------------------------------------

      -- | Genesis length of slot in seconds.
    , ccGenesisSlotDurationSec       :: !Int
      -- | Portion of total stake necessary to vote for or against update.
    , ccGenesisUpdateVoteThd         :: !Double
      -- | Maximum update proposal size in bytes
    , ccGenesisMaxUpdateProposalSize :: !Byte
      -- | Portion of total stake such that block containing UpdateProposal
      -- must contain positive votes for this proposal from stakeholders
      -- owning at least this amount of stake.
    , ccGenesisUpdateProposalThd     :: !Double
      -- | Number of slots after which update is implicitly approved unless
      -- it has more negative votes than positive.
    , ccGenesisUpdateImplicit        :: !Word
      -- | Portion of total stake such that if total stake of issuers of
      -- blocks with some block version is bigger than this portion, this
      -- block version is adopted.
    , ccGenesisUpdateSoftforkThd     :: !Double
      -- | Maximum block size in bytes
    , ccGenesisMaxBlockSize          :: !Byte
      -- | Maximum block header size in bytes
    , ccGenesisMaxHeaderSize         :: !Byte
      -- | Maximum tx size in bytes
    , ccGenesisMaxTxSize             :: !Byte
      -- | Threshold for heavyweight delegation
    , ccGenesisHeavyDelThd           :: !Double
      -- | Eligibility threshold for MPC
    , ccGenesisMpcThd                :: !Double
    }
    deriving (Show, Generic)

coreConstants :: CoreConstants
coreConstants =
    case parseFromCslConfig configParser of
        Left err -> error (toText ("Couldn't parse core config: " ++ err))
        Right x  -> x

instance FromJSON CoreConstants where
    parseJSON = genericParseJSON defaultOptions

instance IsConfig CoreConstants where
    configPrefix = Tagged Nothing

----------------------------------------------------------------------------
-- Constants taken from the config
----------------------------------------------------------------------------

-- | Security parameter which is maximum number of blocks which can be
-- rolled back.
blkSecurityParam :: Integral a => a
blkSecurityParam = fromIntegral . ccK $ coreConstants

-- | Security parameter expressed in number of slots. It uses chain
-- quality property. It's basically @blkSecurityParam / chain_quality@.
slotSecurityParam :: Integral a => a
slotSecurityParam = 2 * blkSecurityParam

-- | Number of slots inside one epoch.
epochSlots :: Integral a => a
epochSlots = 10 * blkSecurityParam

-- | @True@ if current mode is 'Development'.
isDevelopment :: Bool
#ifdef DEV_MODE
isDevelopment = True
#else
isDevelopment = False
#endif

-- | System start time embedded into binary.
staticSysStartRaw :: Microsecond
staticSysStartRaw
    | isDevelopment = error "System start time should be passed \
                              \as a command line argument in dev mode."
    | otherwise     =
          sec $ ccProductionNetworkStartTime coreConstants

-- | Protocol magic constant. Is put to block serialized version to
-- distinguish testnet and realnet (for example, possible usages are
-- wider).
protocolMagic :: Int32
protocolMagic = fromIntegral . ccProtocolMagic $ coreConstants

-- | Number of pre-generated keys
genesisKeysN :: Integral i => i
genesisKeysN = fromIntegral . ccGenesisN $ coreConstants

-- | Size of mem pool will be limited by this value muliplied by block
-- size limit.
memPoolLimitRatio :: Integral i => i
memPoolLimitRatio = fromIntegral . ccMemPoolLimitRatio $ coreConstants

----------------------------------------------------------------------------
-- Asserts
----------------------------------------------------------------------------

{- I'm just going to move them somewhere at some point,
   because they won't work in this module (@neongreen)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

staticAssert
    (ccGenesisMpcThd coreConstants >= 0 &&
     ccGenesisMpcThd coreConstants < 1)
    "genesisMpcThd is not in range [0, 1)"

staticAssert
    (ccGenesisCoreVoteThd coreConstants >= 0 &&
     ccGenesisCoreVoteThd coreConstants < 1)
    "genesisCoreVoteThd is not in range [0, 1)"

staticAssert
    (ccGenesisHeavyDelThd coreConstants >= 0 &&
     ccGenesisHeavyDelThd coreConstants < 1)
    "genesisHeavyDelThd is not in range [0, 1)"

staticAssert
    (ccGenesisCoreProposalThd coreConstants > 0 &&
     ccGenesisCoreProposalThd coreConstants < 1)
    "genesisCoreProposalThd is not in range (0, 1)"

staticAssert
    (ccGenesisCoreSoftforkThd coreConstants > 0 &&
     ccGenesisCoreSoftforkThd coreConstants < 1)
    "genesisCoreSoftforkThd is not in range (0, 1)"

-}
