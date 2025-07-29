"use client"

import { useState, useEffect } from "react"
import {property} from "../../../declarations/property"


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
        (await property.getUserSubmissions(
          principal
        )) || []
        console.log(userSubmissions)
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
            return "status-pending";
          case "processing":
            return "status-processing";
          case "verified":
            return "status-verified";
          case "rejected":
            return "status-rejected";
          case "requires_review":
            return "status-requires_review";
          default:
            return "";
    }
  }

  const getVerdictColor = (verdict: any) => {
    if (!verdict || verdict.length === 0) return "text-gray-500 dark:text-gray-400";
        const verdictKey = Object.keys(verdict[0])[0];
        switch (verdictKey) {
          case "valid":
            return "text-green-600 dark:text-green-400";
          case "invalid":
            return "text-red-600 dark:text-red-400";
          case "requires_review":
            return "text-orange-600 dark:text-orange-400";
          default:
            return "text-gray-500 dark:text-gray-400";
        }
  }

  if (loading) {
    return (
          <div className="container">
            <div className="animate-pulse">
              <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-1/4 mb-6"></div>
              <div className="space-y-4">
                {[...Array(4)].map((_, i) => (
                  <div key={i} className="h-32 bg-gray-200 dark:bg-gray-700 rounded-lg"></div>
                ))}
              </div>
            </div>
          </div>
        );
  }

  return (
    <div className="container">
          <div className="mb-8">
            <div className="flex items-center justify-between">
              <div>
                <h1>Property Verification</h1>
                <p>Submit property documents for AI-powered verification and fraud detection</p>
              </div>
              <button onClick={() => setShowSubmitModal(true)} className="btn btn-primary">
                Submit Document
              </button>
            </div>
          </div>

          {error && (
            <div className="error">
              <p>{error}</p>
            </div>
          )}

          <div className="card mb-8">
            <h3>How Verification Works</h3>
            <div className="grid-4">
              <div className="text-center">
                <div className="text-3xl mb-2">📄</div>
                <h4>1. Submit Document</h4>
                <p>Upload property documents for verification</p>
              </div>
              <div className="text-center">
                <div className="text-3xl mb-2">🤖</div>
                <h4>2. AI Analysis</h4>
                <p>BERT-based model analyzes document authenticity</p>
              </div>
              <div className="text-center">
                <div className="text-3xl mb-2">🔍</div>
                <h4>3. Cross-Reference</h4>
                <p>Check against external registries and databases</p>
              </div>
              <div className="text-center">
                <div className="text-3xl mb-2">✅</div>
                <h4>4. Get Results</h4>
                <p>Receive verification status and confidence score</p>
              </div>
            </div>
          </div>

          <div className="space-y-6">
            <h2>Your Submissions</h2>
            {submissions.length > 0 ? (
              <div className="grid grid-cols-1 gap-6">
                {submissions.map((submission, index) => (
                  <div key={index} className="card">
                    <div className="flex items-center justify-between mb-4">
                      <h3>{submission.title}</h3>
                      <span className={`status-badge ${getStatusColor(submission.status)}`}>
                        {Object.keys(submission.status)[0]}
                      </span>
                    </div>
                    <div className="grid-3 mb-4">
                      <div>
                        <p>Submission ID</p>
                        <p className="font-mono text-sm">{submission.id}</p>
                      </div>
                      <div>
                        <p>Submitted</p>
                        <p className="text-sm">
                          {new Date(Number(submission.timestamp) / 1000000).toLocaleString()}
                        </p>
                      </div>
                      <div>
                        <p>File Size</p>
                        <p className="text-sm">
                          {submission.file_size && submission.file_size.length > 0
                            ? `${(Number(submission.file_size[0]) / 1024).toFixed(1)} KB`
                            : "N/A"}
                        </p>
                      </div>
                    </div>
                    {submission.ai_verification && submission.ai_verification.length > 0 && (
                      <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4 mb-4">
                        <h4>AI Verification Results</h4>
                        <div className="grid-3">
                          <div>
                            <p>Confidence Score</p>
                            <div className="flex items-center space-x-2">
                              <div className="flex-1 progress-bar">
                                <div
                                  className="progress-fill"
                                  style={{ width: `${submission.ai_verification[0].confidence_score * 100}%` }}
                                ></div>
                              </div>
                              <span className="text-sm font-medium">
                                {(submission.ai_verification[0].confidence_score * 100).toFixed(1)}%
                              </span>
                            </div>
                          </div>
                          <div>
                            <p>Verdict</p>
                            <p className={`text-sm font-medium ${getVerdictColor(submission.ai_verification[0].verdict)}`}>
                              {submission.ai_verification[0].verdict && submission.ai_verification[0].verdict.length > 0
                                ? Object.keys(submission.ai_verification[0].verdict[0])[0]
                                : "Pending"}
                            </p>
                          </div>
                          <div>
                            <p>Processed</p>
                            <p className="text-sm">
                              {new Date(Number(submission.ai_verification[0].timestamp) / 1000000).toLocaleString()}
                            </p>
                          </div>
                        </div>
                        {submission.ai_verification[0].red_flags && submission.ai_verification[0].red_flags.length > 0 && (
                          <div className="mt-4">
                            <p className="text-sm mb-2">Red Flags Detected</p>
                            <div className="space-y-1">
                              {submission.ai_verification[0].red_flags.map((flag:any, flagIndex: any) => (
                                <div key={flagIndex} className="flex items-center space-x-2">
                                  <span className="text-red-500">⚠️</span>
                                  <span className="text-sm text-red-600 dark:text-red-400">{flag}</span>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}
                        {submission.ai_verification[0].external_verification &&
                          submission.ai_verification[0].external_verification.length > 0 && (
                            <div className="mt-4">
                              <p className="text-sm mb-2">External Verification</p>
                              <div className="space-y-2">
                                {submission.ai_verification[0].external_verification[0].registry_checks.map(
                                  (check:any, checkIndex:number) => (
                                    <div key={checkIndex} className="flex items-center justify-between text-sm">
                                      <span>{check.registry_name}</span>
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
                    {submission.notes && submission.notes.length > 0 && (
                      <div className="mb-4">
                        <p className="text-sm mb-1">Notes</p>
                        <p className="text-sm">{submission.notes[0]}</p>
                      </div>
                    )}
                    {submission.ipfs_hash && submission.ipfs_hash.length > 0 && (
                      <div className="mb-4">
                        <p className="text-sm mb-1">IPFS Hash</p>
                        <p className="font-mono text-sm break-all">{submission.ipfs_hash[0]}</p>
                      </div>
                    )}
                    <div className="flex space-x-2">
                      <button className="btn btn-secondary">View Details</button>
                      {Object.keys(submission.status)[0] === "verified" && (
                        <button className="btn btn-teal">Use for Tokenization</button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">📄</div>
                <h3>No submissions found</h3>
                <p className="mb-4">Submit your first property document for verification</p>
                <button onClick={() => setShowSubmitModal(true)} className="btn btn-primary">
                  Submit Document
                </button>
              </div>
            )}
          </div>

          {showSubmitModal && (
            <div className="modal">
              <div className="modal-content">
                <div className="modal-header">
                  <h3>Submit Property Document</h3>
                </div>
                <form onSubmit={submitDocument} className="modal-body space-y-4">
                  <div>
                    <label className="block text-sm font-medium mb-1">Document Title</label>
                    <input
                      type="text"
                      name="title"
                      value={submissionForm.title}
                      onChange={handleInputChange}
                      required
                      className="input"
                      placeholder="e.g., Property Deed - 123 Main St"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Upload Document</label>
                    <input
                      type="file"
                      onChange={handleFileSelect}
                      required
                      accept=".pdf,.doc,.docx,.txt,.jpg,.jpeg,.png"
                      className="input"
                    />
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                      Supported formats: PDF, DOC, DOCX, TXT, JPG, JPEG, PNG (Max 10MB)
                    </p>
                  </div>
                  {selectedFile && (
                    <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-3">
                      <p className="text-sm">Selected File</p>
                      <p className="text-sm font-medium">
                        {selectedFile.name} ({(selectedFile.size / 1024).toFixed(1)} KB)
                      </p>
                    </div>
                  )}
                  <div>
                    <label className="block text-sm font-medium mb-1">Additional Notes (Optional)</label>
                    <textarea
                      name="notes"
                      value={submissionForm.notes}
                      onChange={handleInputChange}
                      rows={3}
                      className="textarea"
                      placeholder="Any additional information about this document..."
                    />
                  </div>
                  <div className="info-box">
                    <h4>What happens next?</h4>
                    <ul className="text-sm space-y-1">
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
                      className="flex-1 btn btn-secondary"
                    >
                      Cancel
                    </button>
                    <button type="submit" className="flex-1 btn btn-primary">
                      Submit Document
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
      );
    }

  export default PropertyVerification;
