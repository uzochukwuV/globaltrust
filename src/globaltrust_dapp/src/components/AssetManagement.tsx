"use client"

import { Actor } from "@dfinity/agent"
import { AuthClient } from "@dfinity/auth-client"
import { useState, useEffect } from "react"

const AssetManagement = ({ actors, principal }: {actors : any, principal : string}) => {
  const [assets, setAssets] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string| null>("")
  const [showTokenizeModal, setShowTokenizeModal] = useState(false)
  const [showSaleModal, setShowSaleModal] = useState(false)
  const [selectedAsset, setSelectedAsset] = useState<any>(null)

  // Form states
  const [tokenizeForm, setTokenizeForm] = useState({
    propertyMetadata: "",
    fractionalShares: 100,
    metadata: {
      propertyId: null,
      sharePercentage: 0,
      propertyMetadata: {
        title: "",
        description: "",
        location: "",
        propertyType: "",
        estimatedValue: "",
        ipfsHash: "",
      },
    },
  })

  const [saleForm, setSaleForm] = useState({
    shares: 0,
    pricePerShare: "",
    startTime: "",
    endTime: "",
    minPerUser: 1,
    maxPerUser: 100,
    whitelist: "",
  })

  useEffect(() => {
    loadAssets()
  }, [actors])

  const loadAssets = async () => {
    try {
      setLoading(true)
      setError(null)

      const userTokens = (await actors.propertyToken?.getUserTokens?.(principal)) || []
      setAssets(userTokens)
    } catch (err) {
      console.error("Failed to load assets:", err)
      setError("Failed to load assets")
    } finally {
      setLoading(false)
    }
  }

  const handleTokenizeSubmit = async (e:any) => {
    e.preventDefault()
    try {
      setError(null)

      const result = await actors.propertyToken.mintProperty(
        BigInt(tokenizeForm.propertyMetadata),
        BigInt(tokenizeForm.fractionalShares),
        [tokenizeForm.metadata],
      )

      if ("Ok" in result) {
        await loadAssets()
        setShowTokenizeModal(false)
        setTokenizeForm({
          propertyMetadata: "",
          fractionalShares: 100,
          metadata: {
            propertyId: null,
            sharePercentage: 0,
            propertyMetadata: {
              title: "",
              description: "",
              location: "",
              propertyType: "",
              estimatedValue: "",
              ipfsHash: "",
            },
          },
        })
      } else {
        setError("Failed to tokenize asset: " + Object.keys(result.Err)[0])
      }
    } catch (err) {
      console.error("Failed to tokenize asset:", err)
      setError("Failed to tokenize asset")
    }
  }

  const handleSaleSubmit = async (e:any) => {
    e.preventDefault()
    try {
      setError(null)

      const result = await actors.propertyToken.startSale(
        BigInt((selectedAsset as any).index!),
        BigInt(saleForm.shares),
        BigInt(Number.parseFloat(saleForm.pricePerShare) * 100), // Convert to cents
        BigInt(new Date(saleForm.startTime).getTime() * 1000000),
        BigInt(new Date(saleForm.endTime).getTime() * 1000000),
        BigInt(saleForm.minPerUser),
        BigInt(saleForm.maxPerUser),
        saleForm.whitelist ? [saleForm.whitelist] : [],
      )

      if ("ok" in result) {
        setShowSaleModal(false)
        setSaleForm({
          shares: 0,
          pricePerShare: "",
          startTime: "",
          endTime: "",
          minPerUser: 1,
          maxPerUser: 100,
          whitelist: "",
        })
      } else {
        setError("Failed to start sale: " + Object.keys(result.err)[0])
      }
    } catch (err) {
      console.error("Failed to start sale:", err)
      setError("Failed to start sale")
    }
  }

  const handleInputChange = (form: any, setForm: any) => (e:any) => {
    const { name, value } = e.target
    if (name.includes(".")) {
      const [parent, child] = name.split(".")
      setForm((prev:any) => ({
        ...prev,
        [parent]: {
          ...prev[parent],
          [child]: value,
        },
      }))
    } else {
      setForm((prev:any) => ({
        ...prev,
        [name]: value,
      }))
    }
  }

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-1/4 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="h-64 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-2">Asset Management</h1>
            <p className="text-gray-600 dark:text-gray-400">Tokenize and manage your real-world assets as NFTs</p>
          </div>
          <button
            onClick={() => setShowTokenizeModal(true)}
            className="bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-6 rounded-lg transition-colors duration-200"
          >
            Tokenize Asset
          </button>
        </div>
      </div>

      {error && (
        <div className="mb-6 bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded-lg p-4">
          <p className="text-red-800 dark:text-red-200">{error}</p>
        </div>
      )}

      {/* Assets Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {assets.length > 0 ? (
          assets.map((asset: any, index) => (
            <div
              key={index}
              className="bg-white dark:bg-gray-800 rounded-lg shadow-md border border-gray-200 dark:border-gray-700 overflow-hidden"
            >
              <div className="p-6">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                    Token #{asset!.index.toString()}
                  </h3>
                  <span className="px-2 py-1 bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded-full text-xs font-medium">
                    NFT
                  </span>
                </div>

                {asset.metadata && asset.metadata.length > 0 && asset.metadata[0].propertyMetadata && (
                  <div className="space-y-3 mb-4">
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Title</p>
                      <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                        {asset.metadata[0].propertyMetadata.title || "Untitled Property"}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Location</p>
                      <p className="text-sm text-gray-900 dark:text-gray-100">
                        {asset.metadata[0].propertyMetadata.location || "Location not specified"}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Type</p>
                      <p className="text-sm text-gray-900 dark:text-gray-100">
                        {asset.metadata[0].propertyMetadata.propertyType || "Type not specified"}
                      </p>
                    </div>
                    {asset.metadata[0].sharePercentage > 0 && (
                      <div>
                        <p className="text-sm text-gray-600 dark:text-gray-400">Share Percentage</p>
                        <p className="text-sm text-gray-900 dark:text-gray-100">
                          {(asset.metadata[0].sharePercentage / 100).toFixed(2)}%
                        </p>
                      </div>
                    )}
                  </div>
                )}

                <div className="space-y-2 mb-4">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600 dark:text-gray-400">Owner</span>
                    <span className="font-mono text-gray-900 dark:text-gray-100">
                      {asset.owner.toString().slice(0, 8)}...{asset.owner.toString().slice(-8)}
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600 dark:text-gray-400">Created</span>
                    <span className="text-gray-900 dark:text-gray-100">
                      {new Date(Number(asset.timestamp) / 1000000).toLocaleDateString()}
                    </span>
                  </div>
                </div>

                <div className="flex space-x-2">
                  <button
                    onClick={() => {
                      setSelectedAsset(asset)
                      setShowSaleModal(true)
                    }}
                    className="flex-1 bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200 text-sm"
                  >
                    Start Sale
                  </button>
                  <button className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200 text-sm">
                    Transfer
                  </button>
                </div>
              </div>
            </div>
          ))
        ) : (
          <div className="col-span-full text-center py-12">
            <div className="text-6xl mb-4">🏠</div>
            <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No assets found</h3>
            <p className="text-gray-600 dark:text-gray-400 mb-4">Start by tokenizing your first real-world asset</p>
            <button
              onClick={() => setShowTokenizeModal(true)}
              className="bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-6 rounded-lg transition-colors duration-200"
            >
              Tokenize Asset
            </button>
          </div>
        )}
      </div>

      {/* Tokenize Asset Modal */}
      {showTokenizeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-screen overflow-y-auto">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Tokenize Real-World Asset</h3>
            </div>
            <form onSubmit={handleTokenizeSubmit} className="p-6 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Property Title
                  </label>
                  <input
                    type="text"
                    name="metadata.propertyMetadata.title"
                    value={tokenizeForm.metadata.propertyMetadata.title}
                    onChange={handleInputChange(tokenizeForm, setTokenizeForm)}
                    required
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    placeholder="e.g., Luxury Apartment Downtown"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Property Type
                  </label>
                  <select
                    name="metadata.propertyMetadata.propertyType"
                    value={tokenizeForm.metadata.propertyMetadata.propertyType}
                    onChange={handleInputChange(tokenizeForm, setTokenizeForm)}
                    required
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  >
                    <option value="">Select type</option>
                    <option value="residential">Residential</option>
                    <option value="commercial">Commercial</option>
                    <option value="industrial">Industrial</option>
                    <option value="land">Land</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Description</label>
                <textarea
                  name="metadata.propertyMetadata.description"
                  value={tokenizeForm.metadata.propertyMetadata.description}
                  onChange={handleInputChange(tokenizeForm, setTokenizeForm)}
                  rows={3}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="Describe the property..."
                />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Location</label>
                  <input
                    type="text"
                    name="metadata.propertyMetadata.location"
                    value={tokenizeForm.metadata.propertyMetadata.location}
                    onChange={handleInputChange(tokenizeForm, setTokenizeForm)}
                    required
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    placeholder="e.g., 123 Main St, City, Country"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Estimated Value (USD)
                  </label>
                  <input
                    type="number"
                    name="metadata.propertyMetadata.estimatedValue"
                    value={tokenizeForm.metadata.propertyMetadata.estimatedValue}
                    onChange={handleInputChange(tokenizeForm, setTokenizeForm)}
                    required
                    min="0"
                    step="0.01"
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    placeholder="250000"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Fractional Shares
                  </label>
                  <input
                    type="number"
                    name="fractionalShares"
                    value={tokenizeForm.fractionalShares}
                    onChange={handleInputChange(tokenizeForm, setTokenizeForm)}
                    required
                    min="1"
                    max="10000"
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    IPFS Hash (Document)
                  </label>
                  <input
                    type="text"
                    name="metadata.propertyMetadata.ipfsHash"
                    value={tokenizeForm.metadata.propertyMetadata.ipfsHash}
                    onChange={handleInputChange(tokenizeForm, setTokenizeForm)}
                    required
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    placeholder="QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                  />
                </div>
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowTokenizeModal(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Tokenize Asset
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Start Sale Modal */}
      {showSaleModal && selectedAsset && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full mx-4">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                Start Sale for Token #{selectedAsset.index.toString()}
              </h3>
            </div>
            <form onSubmit={handleSaleSubmit} className="p-6 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Shares to Sell
                  </label>
                  <input
                    type="number"
                    name="shares"
                    value={saleForm.shares}
                    onChange={handleInputChange(saleForm, setSaleForm)}
                    required
                    min="1"
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Price per Share (USD)
                  </label>
                  <input
                    type="number"
                    name="pricePerShare"
                    value={saleForm.pricePerShare}
                    onChange={handleInputChange(saleForm, setSaleForm)}
                    required
                    min="0"
                    step="0.01"
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Start Time</label>
                  <input
                    type="datetime-local"
                    name="startTime"
                    value={saleForm.startTime}
                    onChange={handleInputChange(saleForm, setSaleForm)}
                    required
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">End Time</label>
                  <input
                    type="datetime-local"
                    name="endTime"
                    value={saleForm.endTime}
                    onChange={handleInputChange(saleForm, setSaleForm)}
                    required
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Min per User
                  </label>
                  <input
                    type="number"
                    name="minPerUser"
                    value={saleForm.minPerUser}
                    onChange={handleInputChange(saleForm, setSaleForm)}
                    required
                    min="1"
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Max per User
                  </label>
                  <input
                    type="number"
                    name="maxPerUser"
                    value={saleForm.maxPerUser}
                    onChange={handleInputChange(saleForm, setSaleForm)}
                    required
                    min="1"
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Whitelist Canister (Optional)
                </label>
                <input
                  type="text"
                  name="whitelist"
                  value={saleForm.whitelist}
                  onChange={handleInputChange(saleForm, setSaleForm)}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="Principal ID of whitelist canister"
                />
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowSaleModal(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Start Sale
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default AssetManagement
