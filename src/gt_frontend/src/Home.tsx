import { useState, useEffect } from "react";
import { AuthClient } from "@dfinity/auth-client";
import { createActor as createIdentityActor } from "../../declarations/identity";
import { createActor as createRwaNftActor } from "../../declarations/rwa_nft";
import { createActor as createRwaVerifierActor } from "../../declarations/rwa_verifier";
import { createActor as createMarketplaceActor } from "../../declarations/marketplace";
import { createActor as createLendingActor } from "../../declarations/lending";
import Header from "./components/Header";
import Dashboard from "./components/Dashboard";
import IdentityManagement from "./components/IdentityManagement";
import AssetManagement from "./components/AssetManagement";
import Marketplace from "./components/Marketplace";
import LendingBorrowing from "./components/LendingBorrowing";
import PropertyVerification from "./components/PropertyVerification";
import "./index.scss";

const network = process.env.DFX_NETWORK || "local";
const identityProvider =
  network === "ic" ? "https://identity.ic0.app" : "http://ulvla-h7777-77774-qaacq-cai.localhost:4943";

export default function Home() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authClient, setAuthClient] = useState<AuthClient | null>(null);
  const [actors, setActors] = useState<any>({});
  const [principal, setPrincipal] = useState<string | null>(null);
  const [currentView, setCurrentView] = useState("dashboard");
  const [theme, setTheme] = useState("light");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    initializeAuth();
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle("theme-dark", theme === "dark");
  }, [theme]);

  async function initializeAuth() {
    try {
      const client = await AuthClient.create();
      const isAuthenticated = await client.isAuthenticated();

      setAuthClient(client);
      setIsAuthenticated(isAuthenticated);

      if (isAuthenticated) {
        await updateActors(client);
        setPrincipal(client.getIdentity().getPrincipal().toString());
      }
    } catch (error) {
      console.error("Auth initialization failed:", error);
    } finally {
      setLoading(false);
    }
  }

  async function updateActors(client: AuthClient) {
    const identity = client?.getIdentity();

    const newActors = {
      identity: createIdentityActor(process.env.CANISTER_ID_IDENTITY as string, {
        agentOptions: { identity },
      }),
      rwaNft: createRwaNftActor(process.env.CANISTER_ID_RWA_NFT as string, {
        agentOptions: { identity },
      }),
      rwaVerifier: createRwaVerifierActor(process.env.CANISTER_ID_RWA_VERIFIER as string, {
        agentOptions: { identity },
      }),
      marketplace: createMarketplaceActor(process.env.CANISTER_ID_MARKETPLACE as string, {
        agentOptions: { identity },
      }),
      lending: createLendingActor(process.env.CANISTER_ID_LENDING as string, {
        agentOptions: { identity },
      }),
    };

    setActors(newActors);
  }

  async function login() {
    if (!authClient) return;

    await authClient.login({
      identityProvider,
      onSuccess: async () => {
        setIsAuthenticated(true);
        await updateActors(authClient);
        setPrincipal(authClient.getIdentity().getPrincipal().toString());
      },
    });
  }

  async function logout() {
    if (!authClient) return;

    await authClient.logout();
    setIsAuthenticated(false);
    setPrincipal(null);
    setActors({});
    setCurrentView("dashboard");
  }

  const toggleTheme = () => {
    setTheme((v) => (v === "light" ? "dark" : "light"));
  };

  const renderCurrentView = () => {
    if (!isAuthenticated) {
      return (
        <div className="container hero-center">
          <div className="glass card hero-card">
            <h1 className="hero-title">GlobalTrust</h1>
            <p className="hero-subtitle">Decentralized Cross-Chain Identity & Asset Verification</p>
            <button className="btn btn-primary w-100" onClick={login}>
              Sign In with Internet Identity
            </button>
          </div>
        </div>
      );
    }

    switch (currentView) {
      case "identity":
        return <IdentityManagement actors={actors} principal={principal!} />;
      case "verification":
        return <PropertyVerification actors={actors} principal={principal!} />;
      case "nfts":
        return <AssetManagement actors={actors} principal={principal!} />;
      case "marketplace":
        return <Marketplace actors={actors} principal={principal!} />;
      case "lending":
        return <LendingBorrowing actors={actors} principal={principal!} />;
      default:
        return <Dashboard actors={actors} principal={principal!} />;
    }
  };

  if (loading) {
    return (
      <div className="container hero-center skeleton">
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div>
      {isAuthenticated && (
        <Header
          principal={principal!}
          currentView={currentView}
          setCurrentView={setCurrentView}
          theme={theme}
          toggleTheme={toggleTheme}
          logout={logout}
        />
      )}
      <main>{renderCurrentView()}</main>
    </div>
  );
}