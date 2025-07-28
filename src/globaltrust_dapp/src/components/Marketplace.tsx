"use client"

import { useState, useEffect } from "react"

const Marketplace = ({ actors, principal }: {actors : any, principal : string}) => {
  const [listings, setListings] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [filters, setFilters] = useState({
    status: "",
    minPrice: "",
    maxPrice: "",
    propertyType: "",
    listingType: "",
  })
  const [showOfferModal, setShowOfferModal] = useState(false)
  const [showBidModal, setShowBidModal] = useState(false)
  const [selectedListing, setSelectedListing] = useState(null)
  const [offerAmount, setOfferAmount] = useState("")
  const [bidAmount, setBidAmount] = useState("")

  useEffect(() => {
    loadListings()
  }, [actors])

  const loadListings = async () => {
    try {
      setLoading(true)
      setError(null)

      const allListings = (await actors.propertyMarketplace?.getAllListings?.(null)) || []
      setListings(allListings)
    } catch (err) {
      console.error("Failed to load listings:", err)
      setError("Failed to load listings")
    } finally {
      setLoading(false)
    }
  }

  const submitOffer = async (e: any) => {
    e.preventDefault()
    try {
      setError(null)

      const result = await actors.propertyMarketplace.submitOffer(
        (selectedListing as any).id,
        BigInt(Number.parseFloat(offerAmount) * 100), // Convert to cents
      )

      if ("ok" in result) {
        setShowOfferModal(false)
        setOfferAmount("")
        setSelectedListing(null)
        await loadListings()
      } else {
        setError("Failed to submit offer: " + result.err)
      }
    } catch (err) {
      console.error("Failed to submit offer:", err)
      setError("Failed to submit offer")
    }
  }

  const placeBid = async (e: any) => {
    e.preventDefault()
    try {
      setError(null)

      const result = await actors.propertyMarketplace.placeBid(
        (selectedListing as any).id,
        BigInt(Number.parseFloat(bidAmount) * 100), // Convert to cents
      )

      if ("ok" in result) {
        setShowBidModal(false)
        setBidAmount("")
        setSelectedListing(null)
        await loadListings()
      } else {
        setError("Failed to place bid: " + result.err)
      }
    } catch (err) {
      console.error("Failed to place bid:", err)
      setError("Failed to place bid")
    }
  }

  const getStatusColor = (status: any) => {
    switch (status) {
      case "active":
        return "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
      case "pending":
        return "bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200"
      case "in_escrow":
        return "bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200"
      case "completed":
        return "bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200"
      case "cancelled":
        return "bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200"
      default:
        return "bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200"
    }
  }

  const formatPrice = (price: any) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(price / 100)
  }

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-1/4 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="h-80 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-2">Property Marketplace</h1>
        <p className="text-gray-600 dark:text-gray-400">Browse and trade tokenized real-world assets</p>
      </div>

      {error && (
        <div className="mb-6 bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded-lg p-4">
          <p className="text-red-800 dark:text-red-200">{error}</p>
        </div>
      )}

      {/* Filters */}
      <div className="mb-8 bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Filters</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Status</label>
            <select
              value={filters.status}
              onChange={(e: any) => setFilters({ ...filters, status: e.target.value })}
              className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
            >
              <option value="">All Status</option>
              <option value="active">Active</option>
              <option value="pending">Pending</option>
              <option value="completed">Completed</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Min Price</label>
            <input
              type="number"
              value={filters.minPrice}
              onChange={(e: any) => setFilters({ ...filters, minPrice: e.target.value })}
              className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
              placeholder="0"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Max Price</label>
            <input
              type="number"
              value={filters.maxPrice}
              onChange={(e: any) => setFilters({ ...filters, maxPrice: e.target.value })}
              className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
              placeholder="1000000"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Property Type</label>
            <select
              value={filters.propertyType}
              onChange={(e: any) => setFilters({ ...filters, propertyType: e.target.value })}
              className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
            >
              <option value="">All Types</option>
              <option value="residential">Residential</option>
              <option value="commercial">Commercial</option>
              <option value="industrial">Industrial</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Listing Type</label>
            <select
              value={filters.listingType}
              onChange={(e: any) => setFilters({ ...filters, listingType: e.target.value })}
              className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
            >
              <option value="">All Types</option>
              <option value="sale">Sale</option>
              <option value="auction">Auction</option>
            </select>
          </div>
        </div>
      </div>

      {/* Listings Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {listings.length > 0 ? (
          listings.map((listing, index) => (
            <div
              key={index}
              className="bg-white dark:bg-gray-800 rounded-lg shadow-md border border-gray-200 dark:border-gray-700 overflow-hidden"
            >
              <div className="p-6">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{(listing as any).title}</h3>
                  <div className="flex space-x-2">
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(Object.keys((listing as any).status)[0])}`}
                    >
                      {Object.keys((listing as any).status)[0]}
                    </span>
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium ${
                        Object.keys((listing as any).listing_type)[0] === "sale"
                          ? "bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200"
                          : "bg-purple-100 dark:bg-purple-900 text-purple-800 dark:text-purple-200"
                      }`}
                    >
                      {Object.keys((listing as any).listing_type)[0]}
                    </span>
                  </div>
                </div>

                <div className="space-y-3 mb-4">
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Description</p>
                    <p className="text-sm text-gray-900 dark:text-gray-100">{(listing as any).description}</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Location</p>
                    <p className="text-sm text-gray-900 dark:text-gray-100">{(listing as any).location}</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Property Type</p>
                    <p className="text-sm text-gray-900 dark:text-gray-100">{(listing as any).property_type}</p>
                  </div>
                </div>

                <div className="space-y-2 mb-4">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600 dark:text-gray-400">Price</span>
                    <span className="font-semibold text-gray-900 dark:text-gray-100">{formatPrice((listing as any).price)}</span>
                  </div>
                  {(listing as any).highest_bid && (listing as any).highest_bid.length > 0 && (
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600 dark:text-gray-400">Highest Bid</span>
                      <span className="font-semibold text-teal-600 dark:text-teal-400">
                        {formatPrice((listing as any).highest_bid[0].amount)}
                      </span>
                    </div>
                  )}
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600 dark:text-gray-400">Listed</span>
                    <span className="text-gray-900 dark:text-gray-100">
                      {new Date(Number((listing as any).timestamp) / 1000000).toLocaleDateString()}
                    </span>
                  </div>
                  {(listing as any).end_date && (listing as any).end_date.length > 0 && (
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600 dark:text-gray-400">Ends</span>
                      <span className="text-gray-900 dark:text-gray-100">
                        {new Date(Number((listing as any).end_date[0]) / 1000000).toLocaleDateString()}
                      </span>
                    </div>
                  )}
                </div>

                {Object.keys((listing as any).status)[0] === "active" && !(listing as any).seller.toString().includes(principal) && (
                  <div className="flex space-x-2">
                    {Object.keys((listing as any).listing_type)[0] === "sale" ? (
                      <button
                        onClick={() => {
                          setSelectedListing(listing)
                          setShowOfferModal(true)
                        }}
                        className="flex-1 bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200 text-sm"
                      >
                        Make Offer
                      </button>
                    ) : (
                      <button
                        onClick={() => {
                          setSelectedListing(listing)
                          setShowBidModal(true)
                        }}
                        className="flex-1 bg-purple-500 hover:bg-purple-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200 text-sm"
                      >
                        Place Bid
                      </button>
                    )}
                    <button className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200 text-sm">
                      Details
                    </button>
                  </div>
                )}

                {(listing as any).seller.toString().includes(principal) && (
                  <div className="bg-blue-50 dark:bg-blue-900 rounded-lg p-3">
                    <p className="text-sm text-blue-800 dark:text-blue-200 font-medium">Your Listing</p>
                  </div>
                )}
              </div>
            </div>
          ))
        ) : (
          <div className="col-span-full text-center py-12">
            <div className="text-6xl mb-4">🏪</div>
            <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No listings found</h3>
            <p className="text-gray-600 dark:text-gray-400">Check back later for new property listings</p>
          </div>
        )}
      </div>

      {/* Make Offer Modal */}
      {showOfferModal && selectedListing && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full mx-4">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                Make Offer for {(selectedListing as any).title}
              </h3>
            </div>
            <form onSubmit={submitOffer} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Offer Amount (USD)
                </label>
                <input
                  type="number"
                  value={offerAmount}
                  onChange={(e: any) => setOfferAmount(e.target.value)}
                  required
                  min="0"
                  step="0.01"
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="Enter your offer amount"
                />
              </div>
              <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-3">
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Listed Price: {formatPrice((selectedListing as any).price)}
                </p>
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowOfferModal(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Submit Offer
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Place Bid Modal */}
      {showBidModal && selectedListing && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full mx-4">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                Place Bid for {(selectedListing as any).title}
              </h3>
            </div>
            <form onSubmit={placeBid} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Bid Amount (USD)
                </label>
                <input
                  type="number"
                  value={bidAmount}
                  onChange={(e: any) => setBidAmount(e.target.value)}
                  required
                  min="0"
                  step="0.01"
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="Enter your bid amount"
                />
              </div>
              <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-3 space-y-1">
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Starting Price: {formatPrice((selectedListing as any).price)}
                </p>
                {(selectedListing as any).highest_bid && (selectedListing as any).highest_bid.length > 0 && (
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Current Highest: {formatPrice((selectedListing as any).highest_bid[0].amount)}
                  </p>
                )}
                {(selectedListing as any).reserve_price && (selectedListing as any).reserve_price.length > 0 && (
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Reserve Price: {formatPrice((selectedListing as any).reserve_price[0])}
                  </p>
                )}
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowBidModal(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-purple-500 hover:bg-purple-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Place Bid
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default Marketplace
