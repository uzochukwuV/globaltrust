"use client"

import { useState, useEffect } from "react"
import { AuthClient } from "@dfinity/auth-client"
import { createActor as createIdentityVerifierActor } from "../../declarations/identity"
import { createActor as createPropertyTokenActor } from "../../declarations/property"
import { createActor as createPropertyMarketplaceActor } from "../../declarations/marketplace"
import { createActor as createLendingBorrowingActor } from "../../declarations/lending"
import { createActor as createPropertyVerifierActor } from "../../declarations/property"
import Header from "./components/Header"
import Dashboard from "./components/Dashboard"
import IdentityManagement from "./components/IdentityManagement"
import AssetManagement from "./components/AssetManagement"
import Marketplace from "./components/Marketplace"
import LendingBorrowing from "./components/LendingBorrowing"
import PropertyVerification from "./components/PropertyVerification"
import "./styles/globals.css"
import { Identity } from "@dfinity/agent"

const network = process.env.DFX_NETWORK || "local"
const identityProvider =
  network === "ic" ? "https://identity.ic0.app" : "http://ucwa4-rx777-77774-qaada-cai.localhost:4943"

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [authClient, setAuthClient] = useState<AuthClient | null>(null)
  const [actors, setActors] = useState({})
  const [principal, setPrincipal] = useState<string | null>(null)
  const [currentView, setCurrentView] = useState("dashboard")
  const [theme, setTheme] = useState("light")
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    initializeAuth()
  }, [])

  async function initializeAuth() {
    try {
      const client = await AuthClient.create()
      const isAuthenticated = await client.isAuthenticated()

      setAuthClient(client)
      setIsAuthenticated(isAuthenticated)

      if (isAuthenticated) {
        await updateActors(client)
        setPrincipal(client.getIdentity().getPrincipal().toString())
      }
    } catch (error) {
      console.error("Auth initialization failed:", error)
    } finally {
      setLoading(false)
    }
  }

  async function updateActors(client: AuthClient) {
    const identity = client?.getIdentity()

    const newActors = {
      identityVerifier: createIdentityVerifierActor(process.env.IDENTITY_VERIFIER_CANISTER_ID as string, {
        agentOptions: { identity:identity as  any },
      }),
      propertyToken: createPropertyTokenActor(process.env.PROPERTY_TOKEN_CANISTER_ID as any, {
        agentOptions: { identity:identity as  any },
      }),
      propertyMarketplace: createPropertyMarketplaceActor(process.env.PROPERTY_MARKETPLACE_CANISTER_ID as any, {
        agentOptions: { identity:identity as  any },
      }),
      lendingBorrowing: createLendingBorrowingActor(process.env.LENDING_BORROWING_CANISTER_ID as any, {
        agentOptions: { identity:identity as  any },
      }),
      propertyVerifier: createPropertyVerifierActor(process.env.PROPERTY_VERIFIER_CANISTER_ID as any, {
        agentOptions: { identity:identity as  any },
      }),
    }

    setActors(newActors)
  }

  async function login() {
    if (!authClient) return

    await authClient.login({
      identityProvider,
      onSuccess: async () => {
        await updateActors(authClient)
        setIsAuthenticated(true)
        setPrincipal(authClient.getIdentity().getPrincipal().toString())
      },
    })
  }

  async function logout() {
    if (!authClient) return

    await authClient.logout()
    setIsAuthenticated(false)
    setPrincipal(null)
    setActors({})
    setCurrentView("dashboard")
  }

  const toggleTheme = () => {
    setTheme(theme === "light" ? "dark" : "light")
  }

  const renderCurrentView = () => {
    if (!isAuthenticated) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900">
          <div className="max-w-md w-full space-y-8 p-8">
            <div className="text-center">
              <h1 className="text-4xl font-bold text-gray-900 dark:text-gray-50 mb-4">GlobalTrust</h1>
              <p className="text-lg text-gray-600 dark:text-gray-400 mb-8">
                Decentralized Cross-Chain Identity & Asset Verification Platform
              </p>
              <button
                onClick={login}
                className="w-full bg-blue-700 hover:bg-blue-800 text-white font-medium py-3 px-6 rounded-lg transition-colors duration-200"
              >
                Sign In with Internet Identity
              </button>
            </div>
          </div>
        </div>
      )
    }

    switch (currentView) {
      case "identity":
        return <IdentityManagement actors={actors} principal={principal!} />
      case "assets":
        return <AssetManagement actors={actors} principal={principal!} />
      case "marketplace":
        return <Marketplace actors={actors} principal={principal!} />
      case "lending":
        return <LendingBorrowing actors={actors} principal={principal!} />
      case "verification":
        return <PropertyVerification actors={actors} principal={principal} />
      default:
        return <Dashboard actors={actors} principal={principal!} />
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-700"></div>
      </div>
    )
  }

  return (
    <div className={`min-h-screen ${theme === "dark" ? "dark" : ""}`}>
      <div className="bg-gray-50 dark:bg-gray-900 min-h-screen transition-colors duration-200">
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
        <main className={isAuthenticated ? "pt-16" : ""}>{renderCurrentView()}</main>
      </div>
    </div>
  )
}

export default App
