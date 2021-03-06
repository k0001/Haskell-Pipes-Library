-- | This module provides the proxy transformer equivalent of 'ReaderT'.

{-# LANGUAGE KindSignatures #-}

module Control.Proxy.Trans.Reader (
    -- * ReaderP
    ReaderP(..),
    runReaderP,
    runReaderK,

    -- * Reader operations
    ask,
    asks,
    local,
    withReaderP,
    ) where

import Control.Applicative (Applicative(pure, (<*>)), Alternative(empty, (<|>)))
import Control.Monad (MonadPlus(mzero, mplus))
import Control.Monad.IO.Class (MonadIO(liftIO))
import Control.Monad.Morph (MFunctor(hoist))
import Control.Monad.Trans.Class (MonadTrans(lift))
import Control.Proxy.Class (
    Proxy(request, respond, (->>), (>>~), (>\\), (//>)),
    ProxyInternal(return_P, (?>=), lift_P, liftIO_P, hoist_P, thread_P),
    MonadPlusP(mzero_P, mplus_P) )
import Control.Proxy.Morph (PFunctor(hoistP), PMonad(embedP))
import Control.Proxy.Trans (ProxyTrans(liftP))

-- | The 'Reader' proxy transformer
newtype ReaderP i p a' a b' b (m :: * -> *) r
    = ReaderP { unReaderP :: i -> p a' a b' b m r }

instance (Monad m, Proxy p) => Functor (ReaderP i p a' a b' b m) where
    fmap f p = ReaderP (\i ->
        unReaderP p i ?>= \x ->
        return_P (f x) )

instance (Monad m, Proxy p) => Applicative (ReaderP i p a' a b' b m) where
    pure = return
    p1 <*> p2 = ReaderP (\i ->
        unReaderP p1 i ?>= \f -> 
        unReaderP p2 i ?>= \x -> 
        return_P (f x) )

instance (Monad m, Proxy p) => Monad (ReaderP i p a' a b' b m) where
    return = return_P
    (>>=)  = (?>=)

instance (Proxy p) => MonadTrans (ReaderP i p a' a b' b) where
    lift = lift_P

instance (Proxy p) => MFunctor (ReaderP i p a' a b' b) where
    hoist = hoist_P

instance (MonadIO m, Proxy p) => MonadIO (ReaderP i p a' a b' b m) where
    liftIO = liftIO_P

instance (Monad m, MonadPlusP p) => Alternative (ReaderP i p a' a b' b m) where
    empty = mzero
    (<|>) = mplus

instance (Monad m, MonadPlusP p) => MonadPlus (ReaderP i p a' a b' b m) where
    mzero = mzero_P
    mplus = mplus_P

instance (Proxy p) => ProxyInternal (ReaderP i p) where
    return_P = \r -> ReaderP (\_ -> return_P r)
    m ?>= f  = ReaderP (\i ->
        unReaderP m i ?>= \a -> 
        unReaderP (f a) i )

    lift_P m = ReaderP (\_ -> lift_P m)

    hoist_P nat p = ReaderP (\i -> hoist_P nat (unReaderP p i))

    liftIO_P m = ReaderP (\_ -> liftIO_P m)

    thread_P p s = ReaderP (\i -> thread_P (unReaderP p i) s)

instance (Proxy p) => Proxy (ReaderP i p) where
    fb' ->> p = ReaderP (\i -> (\b' -> unReaderP (fb' b') i) ->> unReaderP p i)
    p >>~ fb  = ReaderP (\i -> unReaderP p i >>~ (\b -> unReaderP (fb b) i))

    request = \a -> ReaderP (\_ -> request a)
    respond = \a -> ReaderP (\_ -> respond a)

    fb' >\\ p = ReaderP (\i -> (\b' -> unReaderP (fb' b') i) >\\ unReaderP p i)
    p //> fb  = ReaderP (\i -> unReaderP p i //> (\b -> unReaderP (fb b) i))

instance (MonadPlusP p) => MonadPlusP (ReaderP i p) where
    mzero_P       = ReaderP (\_ -> mzero_P)
    mplus_P m1 m2 = ReaderP (\i -> mplus_P (unReaderP m1 i) (unReaderP m2 i))

instance ProxyTrans (ReaderP i) where
    liftP m = ReaderP (\_ -> m)

instance PFunctor (ReaderP i) where
    hoistP nat p = ReaderP (\i -> nat (unReaderP p i))

instance PMonad (ReaderP i) where
    embedP nat p = ReaderP (\i -> unReaderP (nat (unReaderP p i)) i)

-- | Run a 'ReaderP' computation, supplying the environment
runReaderP :: i -> ReaderP i p a' a b' b m r -> p a' a b' b m r
runReaderP i m = unReaderP m i
{-# INLINABLE runReaderP #-}

-- | Run a 'ReaderP' \'@K@\'leisli arrow, supplying the environment
runReaderK :: i -> (q -> ReaderP i p a' a b' b m r) -> (q -> p a' a b' b m r)
runReaderK i p q = runReaderP i (p q)
{-# INLINABLE runReaderK #-}

-- | Get the environment
ask :: (Monad m, Proxy p) => ReaderP i p a' a b' b m i
ask = ReaderP return_P
{-# INLINABLE ask #-}

-- | Get a function of the environment
asks :: (Monad m, Proxy p) => (i -> r) -> ReaderP i p a' a b' b m r
asks f = ReaderP (\i -> return_P (f i))
{-# INLINABLE asks #-}

-- | Modify a computation's environment (a specialization of 'withReaderP')
local :: (i -> i) -> ReaderP i p a' a b' b m r -> ReaderP i p a' a b' b m r
local = withReaderP
{-# INLINABLE local #-}

-- | Modify a computation's environment (a more general version of 'local')
withReaderP
    :: (j -> i) -> ReaderP i p a' a b' b m r -> ReaderP j p a' a b' b m r
withReaderP f p = ReaderP (\i -> unReaderP p (f i))
{-# INLINABLE withReaderP #-}
