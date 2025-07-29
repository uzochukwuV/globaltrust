"use client"

import { useState, useEffect } from "react"

const Dashboard = ({ actors, principal }: {actors : any, principal : string}) => {
  const [dashboardData, setDashboardData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadDashboardData()
  }, [actors])

  const loadDashboardData = async () => {
    try {
      setLoading(true)
      setError(null)

      // Load data from multiple canisters
      const [verifierDashboard, marketplaceDashboard, lendingDashboard, identity] = await Promise.all([
        actors.propertyVerifier?.getDashboardData?.() || Promise.resolve(null),
        actors.propertyMarketplace?.getDashboardData?.(principal) || Promise.resolve(null),
        actors.lendingBorrowing?.getDashboardData?.(principal) || Promise.resolve(null),
        actors.identityVerifier?.getIdentity?.(principal) || Promise.resolve(null),
      ])

      setDashboardData({
        verifier: verifierDashboard,
        marketplace: marketplaceDashboard,
        lending: lendingDashboard,
        identity: identity,
      })
    } catch (err) {
      console.error("Failed to load dashboard data:", err)
      setError("Failed to load dashboard data")
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-1/4 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded-lg p-4">
          <p className="text-red-800 dark:text-red-200">{error}</p>
          <button
            onClick={loadDashboardData}
            className="mt-2 bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm"
          >
            Retry
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-2">Dashboard</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Welcome to GlobalTrust - Your decentralized identity and asset platform
        </p>
      </div>

      {/* Identity Status */}
      <div className="mb-8">
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Identity Status</h2>
            <span
              className={`px-3 py-1 rounded-full text-sm font-medium ${
                dashboardData?.identity?.verified
                  ? "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
                  : "bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200"
              }`}
            >
              {dashboardData?.identity?.verified ? "Verified" : "Unverified"}
            </span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="text-center">
              <p className="text-2xl font-bold text-blue-600 dark:text-blue-400">
                {dashboardData?.identity ? "1" : "0"}
              </p>
              <p className="text-sm text-gray-600 dark:text-gray-400">Identity Created</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-teal-600 dark:text-teal-400">
                {dashboardData?.verifier?.total_submissions || 0}
              </p>
              <p className="text-sm text-gray-600 dark:text-gray-400">Documents Submitted</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-emerald-600 dark:text-emerald-400">
                {dashboardData?.verifier?.verified_submissions || 0}
              </p>
              <p className="text-sm text-gray-600 dark:text-gray-400">Documents Verified</p>
            </div>
          </div>
        </div>
      </div>

      {/* Quick Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        {/* Marketplace Stats */}
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Marketplace</h3>
            <span className="text-2xl">🏪</span>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Active Listings</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                {dashboardData?.marketplace?.seller_data?.active_listings || 0}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Total Value</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                ${((dashboardData?.marketplace?.seller_data?.total_listed_value || 0) / 100).toLocaleString()}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Completed Sales</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                {dashboardData?.marketplace?.seller_data?.completed_sales || 0}
              </span>
            </div>
          </div>
        </div>

        {/* Lending Stats */}
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Lending</h3>
            <span className="text-2xl">💰</span>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Active Loans</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                {dashboardData?.lending?.borrower_data?.active_loans || 0}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Total Borrowed</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                ${((dashboardData?.lending?.borrower_data?.total_borrowed || 0) / 100).toLocaleString()}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Credit Score</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                {dashboardData?.lending?.borrower_data?.credit_score || "N/A"}
              </span>
            </div>
          </div>
        </div>

        {/* Verification Stats */}
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Verification</h3>
            <span className="text-2xl">✅</span>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Pending Review</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                {dashboardData?.verifier?.pending_submissions || 0}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">Success Rate</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                {dashboardData?.verifier?.success_rate
                  ? `${(dashboardData.verifier.success_rate * 100).toFixed(1)}%`
                  : "N/A"}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600 dark:text-gray-400">AI Confidence</span>
              <span className="font-medium text-gray-900 dark:text-gray-100">
                {dashboardData?.verifier?.avg_confidence
                  ? `${(dashboardData.verifier.avg_confidence * 100).toFixed(1)}%`
                  : "N/A"}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Recent Activity</h3>
        <div className="space-y-3">
          {dashboardData?.verifier?.recent_submissions?.slice(0, 5).map((submission:any, index:number) => (
            <div
              key={index}
              className="flex items-center justify-between py-2 border-b border-gray-100 dark:border-gray-700 last:border-b-0"
            >
              <div className="flex items-center space-x-3">
                <span className="text-lg">📄</span>
                <div>
                  <p className="font-medium text-gray-900 dark:text-gray-100">
                    {submission.title || "Document Submitted"}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    {new Date(Number(submission.timestamp) / 1000000).toLocaleDateString()}
                  </p>
                </div>
              </div>
              <span
                className={`px-2 py-1 rounded-full text-xs font-medium ${
                  submission.status === "verified"
                    ? "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
                    : submission.status === "pending"
                      ? "bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200"
                      : "bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200"
                }`}
              >
                {submission.status}
              </span>
            </div>
          )) || <p className="text-gray-600 dark:text-gray-400 text-center py-4">No recent activity</p>}
        </div>
      </div>
    </div>
  )
}

export default Dashboard
