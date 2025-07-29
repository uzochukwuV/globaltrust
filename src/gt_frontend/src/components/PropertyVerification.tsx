"use client"

import { useState, useEffect } from "react"

const PropertyVerification = ({ actors, principal }: { actors: any; principal: any }) => {
  const [submissions, setSubmissions] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showSubmitModal, setShowSubmitModal] = useState(false)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)

  // Form state for document submission
  const [submissionForm, setSubmissionForm] = useState({
    title: "",
    documentText: "",
    ipfsHash: "",
    documentType: "",
    fileSize: 0,
    notes: "",
  })

  useEffect(() => {
    loadSubmissions()
  }, [actors])

  const loadSubmissions = async () => {
    try {
      setLoading(true)
      setError(null)

      // Get submissions with filters (user's submissions)
      const userSubmissions =
        (await actors.propertyVerifier?.getSubmissionsWithFilters?.({
          status: null,
          submitter: [principal],
          start_date: null,
          end_date: null,
          limit: null,
          offset: null,
        })) || []

      setSubmissions(userSubmissions)
    } catch (err) {
      console.error("Failed to load submissions:", err)
      setError("Failed to load submissions")
    } finally {
      setLoading(false)
    }
  }

  const handleFileSelect = (e:any) => {
    const file = e.target.files[0]
    if (file) {
      setSelectedFile(file)
      setSubmissionForm((prev) => ({
        ...prev,
        fileSize: file.size,
        documentType: file.type,
      }))

      // Read file content for text extraction (simplified)
      const reader = new FileReader()
      reader.onload = (event) => {
        setSubmissionForm((prev: any) => ({
          ...prev,
          documentText: event?.target?.result?.toString().substring(0, 1000), // First 1000 chars
        }))
      }
      reader.readAsText(file)
    }
  }

  const submitDocument = async (e:any) => {
    e.preventDefault()
    try {
      setError(null)

      if (!selectedFile) {
        setError("Please select a file to upload")
        return
      }

      // In a real implementation, you would upload to IPFS first
      // For demo purposes, we'll use a placeholder IPFS hash
      const mockIpfsHash = "QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

      const result = await actors.propertyVerifier.submitPropertyDocument(
        submissionForm.title,
        submissionForm.documentText,
        [mockIpfsHash],
        [submissionForm.documentType],
        [BigInt(submissionForm.fileSize)],
        submissionForm.notes ? [submissionForm.notes] : [],
      )

      if (result.success) {
        setShowSubmitModal(false)
        setSelectedFile(null)
        setSubmissionForm({
          title: "",
          documentText: "",
          ipfsHash: "",
          documentType: "",
          fileSize: 0,
          notes: "",
        })
        await loadSubmissions()
      } else {
        setError("Failed to submit document: " + result.message)
      }
    } catch (err) {
      console.error("Failed to submit document:", err)
      setError("Failed to submit document")
    }
  }

  const handleInputChange = (e:any) => {
    const { name, value } = e.target
    setSubmissionForm((prev) => ({
      ...prev,
      [name]: value,
    }))
  }

  const getStatusColor = (status: string) => {
    const statusKey = Object.keys(status)[0]
    switch (statusKey) {
      case "pending":
        return "bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200"
      case "processing":
        return "bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200"
      case "verified":
        return "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
      case "rejected":
        return "bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200"
      case "requires_review":
        return "bg-orange-100 dark:bg-orange-900 text-orange-800 dark:text-orange-200"
      default:
        return "bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200"
    }
  }

  const getVerdictColor = (verdict: any) => {
    if (!verdict || verdict.length === 0) return "text-gray-500 dark:text-gray-400"

    const verdictKey = Object.keys(verdict[0])[0]
    switch (verdictKey) {
      case "valid":
        return "text-green-600 dark:text-green-400"
      case "invalid":
        return "text-red-600 dark:text-red-400"
      case "requires_review":
        return "text-orange-600 dark:text-orange-400"
      default:
        return "text-gray-500 dark:text-gray-400"
    }
  }

  if (loading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-1/4 mb-6"></div>
          <div className="space-y-4">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
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
            <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-2">Property Verification</h1>
            <p className="text-gray-600 dark:text-gray-400">
              Submit property documents for AI-powered verification and fraud detection
            </p>
          </div>
          <button
            onClick={() => setShowSubmitModal(true)}
            className="bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-6 rounded-lg transition-colors duration-200"
          >
            Submit Document
          </button>
        </div>
      </div>

      {error && (
        <div className="mb-6 bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded-lg p-4">
          <p className="text-red-800 dark:text-red-200">{error}</p>
        </div>
      )}

      {/* Verification Process Info */}
      <div className="mb-8 bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">How Verification Works</h3>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="text-center">
            <div className="text-3xl mb-2">📄</div>
            <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">1. Submit Document</h4>
            <p className="text-sm text-gray-600 dark:text-gray-400">Upload property documents for verification</p>
          </div>
          <div className="text-center">
            <div className="text-3xl mb-2">🤖</div>
            <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">2. AI Analysis</h4>
            <p className="text-sm text-gray-600 dark:text-gray-400">BERT-based model analyzes document authenticity</p>
          </div>
          <div className="text-center">
            <div className="text-3xl mb-2">🔍</div>
            <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">3. Cross-Reference</h4>
            <p className="text-sm text-gray-600 dark:text-gray-400">Check against external registries and databases</p>
          </div>
          <div className="text-center">
            <div className="text-3xl mb-2">✅</div>
            <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">4. Get Results</h4>
            <p className="text-sm text-gray-600 dark:text-gray-400">Receive verification status and confidence score</p>
          </div>
        </div>
      </div>

      {/* Submissions List */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Your Submissions</h2>

        {submissions.length > 0 ? (
          <div className="grid grid-cols-1 gap-6">
            {submissions.map((submission, index) => (
              <div
                key={index}
                className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700"
              >
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">{submission.title}</h3>
                  <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(submission.status)}`}>
                    {Object.keys(submission.status)[0]}
                  </span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-4">
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Submission ID</p>
                    <p className="font-mono text-sm text-gray-900 dark:text-gray-100">{submission.id}</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Submitted</p>
                    <p className="text-sm text-gray-900 dark:text-gray-100">
                      {new Date(Number(submission.timestamp) / 1000000).toLocaleString()}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400">File Size</p>
                    <p className="text-sm text-gray-900 dark:text-gray-100">
                      {submission.file_size && submission.file_size.length > 0
                        ? `${(Number(submission.file_size[0]) / 1024).toFixed(1)} KB`
                        : "N/A"}
                    </p>
                  </div>
                </div>

                {/* AI Verification Results */}
                {submission.ai_verification && submission.ai_verification.length > 0 && (
                  <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 mb-4">
                    <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-3">AI Verification Results</h4>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div>
                        <p className="text-sm text-gray-600 dark:text-gray-400">Confidence Score</p>
                        <div className="flex items-center space-x-2">
                          <div className="flex-1 bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                            <div
                              className="bg-blue-600 h-2 rounded-full"
                              style={{ width: `${submission.ai_verification[0].confidence_score * 100}%` }}
                            ></div>
                          </div>
                          <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                            {(submission.ai_verification[0].confidence_score * 100).toFixed(1)}%
                          </span>
                        </div>
                      </div>
                      <div>
                        <p className="text-sm text-gray-600 dark:text-gray-400">Verdict</p>
                        <p className={`text-sm font-medium ${getVerdictColor(submission.ai_verification[0].verdict)}`}>
                          {submission.ai_verification[0].verdict && submission.ai_verification[0].verdict.length > 0
                            ? Object.keys(submission.ai_verification[0].verdict[0])[0]
                            : "Pending"}
                        </p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-600 dark:text-gray-400">Processed</p>
                        <p className="text-sm text-gray-900 dark:text-gray-100">
                          {new Date(Number(submission.ai_verification[0].timestamp) / 1000000).toLocaleString()}
                        </p>
                      </div>
                    </div>

                    {/* Red Flags */}
                    {submission.ai_verification[0].red_flags && submission.ai_verification[0].red_flags.length > 0 && (
                      <div className="mt-4">
                        <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">Red Flags Detected</p>
                        <div className="space-y-1">
                          {submission.ai_verification[0].red_flags.map((flag: any, flagIndex: number) => (
                            <div key={flagIndex} className="flex items-center space-x-2">
                              <span className="text-red-500">⚠️</span>
                              <span className="text-sm text-red-600 dark:text-red-400">{flag}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* External Verification */}
                    {submission.ai_verification[0].external_verification &&
                      submission.ai_verification[0].external_verification.length > 0 && (
                        <div className="mt-4">
                          <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">External Verification</p>
                          <div className="space-y-2">
                            {submission.ai_verification[0].external_verification[0].registry_checks.map(
                              (check: any, checkIndex: number) => (
                                <div key={checkIndex} className="flex items-center justify-between text-sm">
                                  <span className="text-gray-900 dark:text-gray-100">{check.registry_name}</span>
                                  <span
                                    className={
                                      check.verified
                                        ? "text-green-600 dark:text-green-400"
                                        : "text-red-600 dark:text-red-400"
                                    }
                                  >
                                    {check.verified ? "✓ Verified" : "✗ Not Found"}
                                  </span>
                                </div>
                              ),
                            )}
                          </div>
                        </div>
                      )}
                  </div>
                )}

                {/* Notes */}
                {submission.notes && submission.notes.length > 0 && (
                  <div className="mb-4">
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Notes</p>
                    <p className="text-sm text-gray-900 dark:text-gray-100">{submission.notes[0]}</p>
                  </div>
                )}

                {/* IPFS Hash */}
                {submission.ipfs_hash && submission.ipfs_hash.length > 0 && (
                  <div className="mb-4">
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">IPFS Hash</p>
                    <p className="font-mono text-sm text-gray-900 dark:text-gray-100 break-all">
                      {submission.ipfs_hash[0]}
                    </p>
                  </div>
                )}

                {/* Actions */}
                <div className="flex space-x-2">
                  <button className="bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200 text-sm">
                    View Details
                  </button>
                  {Object.keys(submission.status)[0] === "verified" && (
                    <button className="bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200 text-sm">
                      Use for Tokenization
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">📄</div>
            <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No submissions found</h3>
            <p className="text-gray-600 dark:text-gray-400 mb-4">
              Submit your first property document for verification
            </p>
            <button
              onClick={() => setShowSubmitModal(true)}
              className="bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-6 rounded-lg transition-colors duration-200"
            >
              Submit Document
            </button>
          </div>
        )}
      </div>

      {/* Submit Document Modal */}
      {showSubmitModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-screen overflow-y-auto">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Submit Property Document</h3>
            </div>
            <form onSubmit={submitDocument} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Document Title
                </label>
                <input
                  type="text"
                  name="title"
                  value={submissionForm.title}
                  onChange={handleInputChange}
                  required
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="e.g., Property Deed - 123 Main St"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Upload Document
                </label>
                <input
                  type="file"
                  onChange={handleFileSelect}
                  required
                  accept=".pdf,.doc,.docx,.txt,.jpg,.jpeg,.png"
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                />
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  Supported formats: PDF, DOC, DOCX, TXT, JPG, JPEG, PNG (Max 10MB)
                </p>
              </div>

              {selectedFile && (
                <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-3">
                  <p className="text-sm text-gray-600 dark:text-gray-400">Selected File</p>
                  <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    {selectedFile.name} ({((selectedFile as any).size / 1024).toFixed(1)} KB)
                  </p>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Additional Notes (Optional)
                </label>
                <textarea
                  name="notes"
                  value={submissionForm.notes}
                  onChange={handleInputChange}
                  rows={3}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="Any additional information about this document..."
                />
              </div>

              <div className="bg-blue-50 dark:bg-blue-900 rounded-lg p-4">
                <h4 className="font-medium text-blue-900 dark:text-blue-100 mb-2">What happens next?</h4>
                <ul className="text-sm text-blue-800 dark:text-blue-200 space-y-1">
                  <li>• Your document will be uploaded to IPFS for immutable storage</li>
                  <li>• AI model will analyze the document for authenticity</li>
                  <li>• External registries will be checked for verification</li>
                  <li>• You'll receive a confidence score and verification status</li>
                </ul>
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowSubmitModal(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Submit Document
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default PropertyVerification
