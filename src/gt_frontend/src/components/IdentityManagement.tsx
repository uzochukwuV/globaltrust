"use client"

import { useState, useEffect } from "react"

const IdentityManagement = ({ actors, principal }: {actors : any, principal : string}) => {
  const [identity, setIdentity] = useState<any>(null)
  const [credentials, setCredentials] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showAddCredential, setShowAddCredential] = useState(false)

  // Form state for adding credentials
  const [credentialForm, setCredentialForm] = useState({
    credentialType: "",
    issuer: "",
    issuedAt: "",
    expirationDate: "",
    credentialHash: "",
  })

  useEffect(() => {
    loadIdentityData()
  }, [actors])

  const loadIdentityData = async () => {
    try {
      setLoading(true)
      setError(null)

      const [identityData, credentialsData] = await Promise.all([
        actors.identityVerifier?.getIdentity?.(principal),
        actors.identityVerifier?.getVerifiableCredentials?.(principal),
      ])

      setIdentity(identityData)
      setCredentials(credentialsData || [])
    } catch (err) {
      console.error("Failed to load identity data:", err)
      setError("Failed to load identity data")
    } finally {
      setLoading(false)
    }
  }

  const registerIdentity = async () => {
    try {
      setError(null)
      const result = await actors.identityVerifier.registerIdentity()

      if ("ok" in result) {
        setIdentity(result.ok)
      } else {
        setError("Failed to register identity: " + Object.keys(result.err)[0])
      }
    } catch (err) {
      console.error("Failed to register identity:", err)
      setError("Failed to register identity")
    }
  }

  const addCredential = async (e:any) => {
    e.preventDefault()
    try {
      setError(null)

      const result = await actors.identityVerifier.addVerifiableCredential(
        credentialForm.credentialType,
        credentialForm.issuer,
        BigInt(new Date(credentialForm.issuedAt).getTime() * 1000000),
        credentialForm.expirationDate ? [BigInt(new Date(credentialForm.expirationDate).getTime() * 1000000)] : [],
        credentialForm.credentialHash,
      )

      if ("ok" in result) {
        console.log(result.ok)
        setCredentials([...credentials, result.ok])
        setCredentialForm({
          credentialType: "",
          issuer: "",
          issuedAt: "",
          expirationDate: "",
          credentialHash: "",
        })
        setShowAddCredential(false)
      } else {
        setError("Failed to add credential: " + Object.keys(result.err)[0])
      }
    } catch (err) {
      console.error("Failed to add credential:", err)
      setError("Failed to add credential")
    }
  }

  const handleInputChange = (e:any) => {
    const { name, value } = e.target
    setCredentialForm((prev) => ({
      ...prev,
      [name]: value,
    }))
  }

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-1/4 mb-6"></div>
          <div className="space-y-4">
            <div className="h-32 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
            <div className="h-48 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-2">Identity Management</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Manage your self-sovereign identity and verifiable credentials
        </p>
      </div>

      {error && (
        <div className="mb-6 bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded-lg p-4">
          <p className="text-red-800 dark:text-red-200">{error}</p>
        </div>
      )}

      {/* Identity Status */}
      <div className="mb-8">
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Identity Status</h2>
            {identity && (
              <span
                className={`px-3 py-1 rounded-full text-sm font-medium ${
                  identity.verified
                    ? "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
                    : "bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200"
                }`}
              >
                {identity.verified ? "Verified" : "Unverified"}
              </span>
            )}
          </div>

          {identity ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Principal ID</p>
                <p className="font-mono text-sm text-gray-900 dark:text-gray-100 break-all">{identity.id.toString()}</p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Created At</p>
                <p className="text-sm text-gray-900 dark:text-gray-100">
                  {new Date(Number(identity.createdAt) / 1000000).toLocaleString()}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Last Updated</p>
                <p className="text-sm text-gray-900 dark:text-gray-100">
                  {new Date(Number(identity.updatedAt) / 1000000).toLocaleString()}
                </p>
              </div>
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Credentials</p>
                <p className="text-sm text-gray-900 dark:text-gray-100">
                  {credentials.length} credential{credentials.length !== 1 ? "s" : ""}
                </p>
              </div>
            </div>
          ) : (
            <div className="text-center py-8">
              <p className="text-gray-600 dark:text-gray-400 mb-4">
                No identity found. Create your self-sovereign identity to get started.
              </p>
              <button
                onClick={registerIdentity}
                className="bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-6 rounded-lg transition-colors duration-200"
              >
                Create Identity
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Verifiable Credentials */}
      {identity && (
        <div className="mb-8">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md border border-gray-200 dark:border-gray-700">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Verifiable Credentials</h2>
                <button
                  onClick={() => setShowAddCredential(true)}
                  className="bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Add Credential
                </button>
              </div>
            </div>

            <div className="p-6">
              {credentials.length > 0 ? (
                <div className="space-y-4">
                  {credentials.map((credential, index) => (
                    <div key={index} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                      <div className="flex items-center justify-between mb-3">
                        <h3 className="font-semibold text-gray-900 dark:text-gray-100">{credential.credentialType}</h3>
                        <span
                          className={`px-2 py-1 rounded-full text-xs font-medium ${
                            credential.status === "Valid"
                              ? "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
                              : credential.status === "Expired"
                                ? "bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200"
                                : "bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200"
                          }`}
                        >
                          {credential.status}
                        </span>
                      </div>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                        <div>
                          <p className="text-gray-600 dark:text-gray-400">Issuer</p>
                          <p className="text-gray-900 dark:text-gray-100">{credential.issuer}</p>
                        </div>
                        <div>
                          <p className="text-gray-600 dark:text-gray-400">Issued At</p>
                          <p className="text-gray-900 dark:text-gray-100">
                            {new Date(Number(credential.issuedAt) / 1000000).toLocaleDateString()}
                          </p>
                        </div>
                        <div>
                          <p className="text-gray-600 dark:text-gray-400">Credential Hash</p>
                          <p className="font-mono text-gray-900 dark:text-gray-100 break-all">
                            {credential.credentialHash}
                          </p>
                        </div>
                        {credential.expirationDate && credential.expirationDate.length > 0 && (
                          <div>
                            <p className="text-gray-600 dark:text-gray-400">Expires At</p>
                            <p className="text-gray-900 dark:text-gray-100">
                              {new Date(Number(credential.expirationDate[0]) / 1000000).toLocaleDateString()}
                            </p>
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-600 dark:text-gray-400 text-center py-8">
                  No credentials added yet. Add your first credential to get started.
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Add Credential Modal */}
      {showAddCredential && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full mx-4">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Add Verifiable Credential</h3>
            </div>
            <form onSubmit={addCredential} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Credential Type
                </label>
                <select
                  name="credentialType"
                  value={credentialForm.credentialType}
                  onChange={handleInputChange}
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                >
                  <option value="">Select type</option>
                  <option value="Passport">Passport</option>
                  <option value="GovernmentID">Government ID</option>
                  <option value="PropertyDeed">Property Deed</option>
                  <option value="AcademicCredential">Academic Credential</option>
                  <option value="ProfessionalLicense">Professional License</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Issuer</label>
                <input
                  type="text"
                  name="issuer"
                  value={credentialForm.issuer}
                  onChange={handleInputChange}
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="e.g., Government of Country"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Issued Date</label>
                <input
                  type="date"
                  name="issuedAt"
                  value={credentialForm.issuedAt}
                  onChange={handleInputChange}
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Expiration Date (Optional)
                </label>
                <input
                  type="date"
                  name="expirationDate"
                  value={credentialForm.expirationDate}
                  onChange={handleInputChange}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Document Hash (IPFS CID)
                </label>
                <input
                  type="text"
                  name="credentialHash"
                  value={credentialForm.credentialHash}
                  onChange={handleInputChange}
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                />
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowAddCredential(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Add Credential
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default IdentityManagement
