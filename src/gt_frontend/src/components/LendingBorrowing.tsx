"use client"

import { useState, useEffect } from "react"
import { LoanApplication } from "../../../declarations/lending/lending.did"

const LendingBorrowing = ({ actors, principal }: {actors : any, principal : string}) => {
  const [loans, setLoans] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState("borrow")
  const [showLoanModal, setShowLoanModal] = useState(false)
  const [showPaymentModal, setShowPaymentModal] = useState(false)
  const [selectedLoan, setSelectedLoan] = useState<any>(null)

  // Form states
  const [loanApplication, setLoanApplication] = useState({
    borrower: principal,
    requested_amount: "",
    loan_purpose: "",
    employment_info: {
      employer_name: "",
      job_title: "",
      employment_duration: "",
      monthly_income: "",
      employment_type: "full-time",
      verified: false,
    },
    financial_info: {
      monthly_income: "",
      monthly_expenses: "",
      existing_debts: "",
      assets_value: "",
      bank_statements_provided: false,
      tax_returns_provided: false,
    },
    property_info: {
      submission_id: "",
      estimated_value: "",
      property_type: "residential",
      location: "",
      appraisal_date: null,
      insurance_info: null,
    },
    additional_documents: [],
    duration: "",
  })

  const [paymentForm, setPaymentForm] = useState({
    amount: "",
    payment_type: "regular",
  })

  useEffect(() => {
    loadLoans()
  }, [actors])

  const loadLoans = async () => {
    try {
      setLoading(true)
      setError(null)

      const allLoans = (await actors.lendingBorrowing?.getAllLoans2?.(null)) || []
      setLoans(allLoans)
    } catch (err) {
      console.error("Failed to load loans:", err)
      setError("Failed to load loans")
    } finally {
      setLoading(false)
    }
  }

  const submitLoanApplication = async (e:any) => {
    e.preventDefault()
    try {
      setError(null)

      const result = await actors.lendingBorrowing.submitLoanApplication({
        ...loanApplication,
        requested_amount: BigInt(Number.parseFloat(loanApplication.requested_amount) * 100),
        duration: BigInt(Number.parseInt(loanApplication.duration) * 24 * 60 * 60 * 1000000000), // Convert days to nanoseconds
        employment_info: {
          ...loanApplication.employment_info,
          employment_duration: BigInt(Number.parseInt(loanApplication.employment_info.employment_duration)),
          monthly_income: BigInt(Number.parseFloat(loanApplication.employment_info.monthly_income) * 100),
        },
        financial_info: {
          ...loanApplication.financial_info,
          monthly_income: BigInt(Number.parseFloat(loanApplication.financial_info.monthly_income) * 100),
          monthly_expenses: BigInt(Number.parseFloat(loanApplication.financial_info.monthly_expenses) * 100),
          existing_debts: BigInt(Number.parseFloat(loanApplication.financial_info.existing_debts) * 100),
          assets_value: BigInt(Number.parseFloat(loanApplication.financial_info.assets_value) * 100),
        },
        property_info: {
          ...loanApplication.property_info,
          estimated_value: BigInt(Number.parseFloat(loanApplication.property_info.estimated_value) * 100),
        },
      })

      if (result.success) {
        setShowLoanModal(false)
        await loadLoans()
        // Reset form
        setLoanApplication({
          borrower: principal,
          requested_amount: "",
          loan_purpose: "",
          employment_info: {
            employer_name: "",
            job_title: "",
            employment_duration: "",
            monthly_income: "",
            employment_type: "full-time",
            verified: false,
          },
          financial_info: {
            monthly_income: "",
            monthly_expenses: "",
            existing_debts: "",
            assets_value: "",
            bank_statements_provided: false,
            tax_returns_provided: false,
          },
          property_info: {
            submission_id: "",
            estimated_value: "",
            property_type: "residential",
            location: "",
            appraisal_date: null,
            insurance_info: null,
          },
          additional_documents: [],
          duration: "",
        })
      } else {
        setError("Failed to submit loan application: " + result.message)
      }
    } catch (err) {
      console.error("Failed to submit loan application:", err)
      setError("Failed to submit loan application")
    }
  }

  const makePayment = async (e:any) => {
    e.preventDefault()
    try {
      setError(null)

      const paymentType = { [paymentForm.payment_type]: null }
      const result = await actors.lendingBorrowing.makePayment(
        selectedLoan.id,
        BigInt(Number.parseFloat(paymentForm.amount) * 100),
        paymentType,
      )

      if ("ok" in result) {
        setShowPaymentModal(false)
        setPaymentForm({ amount: "", payment_type: "regular" })
        setSelectedLoan(null)
        await loadLoans()
      } else {
        setError("Failed to make payment: " + result.err)
      }
    } catch (err) {
      console.error("Failed to make payment:", err)
      setError("Failed to make payment")
    }
  }

  const fundLoan = async (loanId:any) => {
    try {
      setError(null)

      const result = await actors.lendingBorrowing.fundLoan(loanId)

      if ("ok" in result) {
        await loadLoans()
      } else {
        setError("Failed to fund loan: " + result.err)
      }
    } catch (err) {
      console.error("Failed to fund loan:", err)
      setError("Failed to fund loan")
    }
  }

  const handleInputChange = (e:any) => {
    const { name, value, type, checked } = e.target

    if (name.includes(".")) {
      const [parent, child] = name.split(".")
      setLoanApplication((prev : any) => ({
        ...prev,
        [parent]: {
          ...prev[parent],
          [child]: type === "checkbox" ? checked : value,
        },
      }))
    } else {
      setLoanApplication((prev) => ({
        ...prev,
        [name]: type === "checkbox" ? checked : value,
      }))
    }
  }

  const getStatusColor = (status:any) => {
    const statusKey = Object.keys(status)[0]
    switch (statusKey) {
      case "pending":
        return "bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200"
      case "approved":
        return "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
      case "funded":
        return "bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200"
      case "repaying":
        return "bg-teal-100 dark:bg-teal-900 text-teal-800 dark:text-teal-200"
      case "repaid":
        return "bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200"
      case "defaulted":
        return "bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200"
      default:
        return "bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200"
    }
  }

  const formatCurrency = (amount: any) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(amount / 100)
  }

  const userLoans = loans.filter(
    (loan) =>
      loan.borrower.toString() === principal ||
      (loan.lender && loan.lender.length > 0 && loan.lender[0].toString() === principal),
  )

  const availableLoans = loans.filter(
    (loan) => Object.keys(loan.status)[0] === "approved" && loan.borrower.toString() !== principal,
  )

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
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100 mb-2">Lending & Borrowing</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Use tokenized assets as collateral for loans or invest in lending opportunities
        </p>
      </div>

      {error && (
        <div className="mb-6 bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-700 rounded-lg p-4">
          <p className="text-red-800 dark:text-red-200">{error}</p>
        </div>
      )}

      {/* Tabs */}
      <div className="mb-8">
        <div className="border-b border-gray-200 dark:border-gray-700">
          <nav className="-mb-px flex space-x-8">
            <button
              onClick={() => setActiveTab("borrow")}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === "borrow"
                  ? "border-blue-500 text-blue-600 dark:text-blue-400"
                  : "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-gray-300"
              }`}
            >
              Borrow
            </button>
            <button
              onClick={() => setActiveTab("lend")}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === "lend"
                  ? "border-blue-500 text-blue-600 dark:text-blue-400"
                  : "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-gray-300"
              }`}
            >
              Lend
            </button>
            <button
              onClick={() => setActiveTab("my-loans")}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === "my-loans"
                  ? "border-blue-500 text-blue-600 dark:text-blue-400"
                  : "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-gray-300"
              }`}
            >
              My Loans ({userLoans.length})
            </button>
          </nav>
        </div>
      </div>

      {/* Borrow Tab */}
      {activeTab === "borrow" && (
        <div className="space-y-6">
          <div className="flex justify-between items-center">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Apply for a Loan</h2>
            <button
              onClick={() => setShowLoanModal(true)}
              className="bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-6 rounded-lg transition-colors duration-200"
            >
              Apply for Loan
            </button>
          </div>

          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">How it Works</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="text-center">
                <div className="text-3xl mb-2">📄</div>
                <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">1. Submit Application</h4>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Provide your financial information and property details
                </p>
              </div>
              <div className="text-center">
                <div className="text-3xl mb-2">✅</div>
                <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">2. Get Approved</h4>
                <p className="text-sm text-gray-600 dark:text-gray-400">AI-powered risk assessment and lender review</p>
              </div>
              <div className="text-center">
                <div className="text-3xl mb-2">💰</div>
                <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">3. Receive Funding</h4>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Get funded by lenders and start making payments
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Lend Tab */}
      {activeTab === "lend" && (
        <div className="space-y-6">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">Available Lending Opportunities</h2>

          <div className="grid grid-cols-1 gap-6">
            {availableLoans.length > 0 ? (
              availableLoans.map((loan, index) => (
                <div
                  key={index}
                  className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700"
                >
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Loan #{loan.id}</h3>
                    <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(loan.status)}`}>
                      {Object.keys(loan.status)[0]}
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Loan Amount</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">{formatCurrency(loan.amount)}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Interest Rate</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">
                        {(loan.interest_rate * 100).toFixed(2)}%
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Duration</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">
                        {Math.round(Number(loan.duration) / (24 * 60 * 60 * 1000000000))} days
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Monthly Payment</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">
                        {formatCurrency(loan.monthly_payment)}
                      </p>
                    </div>
                  </div>

                  <div className="mb-4">
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Purpose</p>
                    <p className="text-gray-900 dark:text-gray-100">{loan.loan_purpose}</p>
                  </div>

                  <div className="flex justify-between items-center">
                    <div className="text-sm text-gray-600 dark:text-gray-400">
                      Credit Score: {loan.credit_score && loan.credit_score.length > 0 ? loan.credit_score[0] : "N/A"}
                    </div>
                    <button
                      onClick={() => fundLoan(loan.id)}
                      className="bg-teal-500 hover:bg-teal-600 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                    >
                      Fund Loan
                    </button>
                  </div>
                </div>
              ))
            ) : (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">💰</div>
                <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">
                  No lending opportunities available
                </h3>
                <p className="text-gray-600 dark:text-gray-400">Check back later for new loan applications</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* My Loans Tab */}
      {activeTab === "my-loans" && (
        <div className="space-y-6">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">My Loans</h2>

          <div className="grid grid-cols-1 gap-6">
            {userLoans.length > 0 ? (
              userLoans.map((loan, index) => (
                <div
                  key={index}
                  className="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-200 dark:border-gray-700"
                >
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center space-x-3">
                      <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Loan #{loan.id}</h3>
                      <span
                        className={`px-2 py-1 rounded-full text-xs font-medium ${
                          loan.borrower.toString() === principal
                            ? "bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200"
                            : "bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200"
                        }`}
                      >
                        {loan.borrower.toString() === principal ? "Borrower" : "Lender"}
                      </span>
                    </div>
                    <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(loan.status)}`}>
                      {Object.keys(loan.status)[0]}
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Loan Amount</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">{formatCurrency(loan.amount)}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Interest Rate</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">
                        {(loan.interest_rate * 100).toFixed(2)}%
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Monthly Payment</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">
                        {formatCurrency(loan.monthly_payment)}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Progress</p>
                      <p className="font-semibold text-gray-900 dark:text-gray-100">
                        {loan.payments_made}/{loan.total_payments}
                      </p>
                    </div>
                  </div>

                  {loan.borrower.toString() === principal &&
                    (Object.keys(loan.status)[0] === "funded" || Object.keys(loan.status)[0] === "repaying") && (
                      <div className="flex justify-end">
                        <button
                          onClick={() => {
                            setSelectedLoan(loan)
                            setShowPaymentModal(true)
                          }}
                          className="bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                        >
                          Make Payment
                        </button>
                      </div>
                    )}
                </div>
              ))
            ) : (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">📋</div>
                <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100 mb-2">No loans found</h3>
                <p className="text-gray-600 dark:text-gray-400">
                  Apply for a loan or fund existing applications to get started
                </p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Loan Application Modal */}
      {showLoanModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-screen overflow-y-auto">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Loan Application</h3>
            </div>
            <form onSubmit={submitLoanApplication} className="p-6 space-y-6">
              {/* Basic Information */}
              <div>
                <h4 className="text-md font-semibold text-gray-900 dark:text-gray-100 mb-4">Basic Information</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Requested Amount (USD)
                    </label>
                    <input
                      type="number"
                      name="requested_amount"
                      value={loanApplication.requested_amount}
                      onChange={handleInputChange}
                      required
                      min="1000"
                      step="0.01"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Loan Duration (Days)
                    </label>
                    <input
                      type="number"
                      name="duration"
                      value={loanApplication.duration}
                      onChange={handleInputChange}
                      required
                      min="30"
                      max="10950"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                </div>
                <div className="mt-4">
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Loan Purpose
                  </label>
                  <textarea
                    name="loan_purpose"
                    value={loanApplication.loan_purpose}
                    onChange={handleInputChange}
                    required
                    rows={3}
                    className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    placeholder="Describe the purpose of this loan..."
                  />
                </div>
              </div>

              {/* Employment Information */}
              <div>
                <h4 className="text-md font-semibold text-gray-900 dark:text-gray-100 mb-4">Employment Information</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Employer Name
                    </label>
                    <input
                      type="text"
                      name="employment_info.employer_name"
                      value={loanApplication.employment_info.employer_name}
                      onChange={handleInputChange}
                      required
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Job Title</label>
                    <input
                      type="text"
                      name="employment_info.job_title"
                      value={loanApplication.employment_info.job_title}
                      onChange={handleInputChange}
                      required
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Employment Duration (Months)
                    </label>
                    <input
                      type="number"
                      name="employment_info.employment_duration"
                      value={loanApplication.employment_info.employment_duration}
                      onChange={handleInputChange}
                      required
                      min="0"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Monthly Income (USD)
                    </label>
                    <input
                      type="number"
                      name="employment_info.monthly_income"
                      value={loanApplication.employment_info.monthly_income}
                      onChange={handleInputChange}
                      required
                      min="0"
                      step="0.01"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                </div>
              </div>

              {/* Property Information */}
              <div>
                <h4 className="text-md font-semibold text-gray-900 dark:text-gray-100 mb-4">
                  Property Information (Collateral)
                </h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Property Submission ID
                    </label>
                    <input
                      type="text"
                      name="property_info.submission_id"
                      value={loanApplication.property_info.submission_id}
                      onChange={handleInputChange}
                      required
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                      placeholder="Property verification submission ID"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Estimated Value (USD)
                    </label>
                    <input
                      type="number"
                      name="property_info.estimated_value"
                      value={loanApplication.property_info.estimated_value}
                      onChange={handleInputChange}
                      required
                      min="0"
                      step="0.01"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Property Type
                    </label>
                    <select
                      name="property_info.property_type"
                      value={loanApplication.property_info.property_type}
                      onChange={handleInputChange}
                      required
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    >
                      <option value="residential">Residential</option>
                      <option value="commercial">Commercial</option>
                      <option value="industrial">Industrial</option>
                      <option value="land">Land</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Location</label>
                    <input
                      type="text"
                      name="property_info.location"
                      value={loanApplication.property_info.location}
                      onChange={handleInputChange}
                      required
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                      placeholder="Property location"
                    />
                  </div>
                </div>
              </div>

              {/* Financial Information */}
              <div>
                <h4 className="text-md font-semibold text-gray-900 dark:text-gray-100 mb-4">Financial Information</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Monthly Income (USD)
                    </label>
                    <input
                      type="number"
                      name="financial_info.monthly_income"
                      value={loanApplication.financial_info.monthly_income}
                      onChange={handleInputChange}
                      required
                      min="0"
                      step="0.01"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Monthly Expenses (USD)
                    </label>
                    <input
                      type="number"
                      name="financial_info.monthly_expenses"
                      value={loanApplication.financial_info.monthly_expenses}
                      onChange={handleInputChange}
                      required
                      min="0"
                      step="0.01"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Existing Debts (USD)
                    </label>
                    <input
                      type="number"
                      name="financial_info.existing_debts"
                      value={loanApplication.financial_info.existing_debts}
                      onChange={handleInputChange}
                      required
                      min="0"
                      step="0.01"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Assets Value (USD)
                    </label>
                    <input
                      type="number"
                      name="financial_info.assets_value"
                      value={loanApplication.financial_info.assets_value}
                      onChange={handleInputChange}
                      required
                      min="0"
                      step="0.01"
                      className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                    />
                  </div>
                </div>
                <div className="mt-4 space-y-2">
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      name="financial_info.bank_statements_provided"
                      checked={loanApplication.financial_info.bank_statements_provided}
                      onChange={handleInputChange}
                      className="mr-2"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">Bank statements provided</span>
                  </label>
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      name="financial_info.tax_returns_provided"
                      checked={loanApplication.financial_info.tax_returns_provided}
                      onChange={handleInputChange}
                      className="mr-2"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">Tax returns provided</span>
                  </label>
                </div>
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowLoanModal(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Submit Application
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Payment Modal */}
      {showPaymentModal && selectedLoan && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full mx-4">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                Make Payment for Loan #{selectedLoan.id}
              </h3>
            </div>
            <form onSubmit={makePayment} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Payment Amount (USD)
                </label>
                <input
                  type="number"
                  value={paymentForm.amount}
                  onChange={(e:any) => setPaymentForm({ ...paymentForm, amount: e.target.value })}
                  required
                  min="0"
                  step="0.01"
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="Enter payment amount"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Payment Type</label>
                <select
                  value={paymentForm.payment_type}
                  onChange={(e:any) => setPaymentForm({ ...paymentForm, payment_type: e.target.value })}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-md px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                >
                  <option value="regular">Regular Payment</option>
                  <option value="extra">Extra Payment</option>
                  <option value="final">Final Payment</option>
                </select>
              </div>
              <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-3 space-y-1">
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Monthly Payment: {formatCurrency(selectedLoan.monthly_payment)}
                </p>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Payments Made: {selectedLoan.payments_made}/{selectedLoan.total_payments}
                </p>
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowPaymentModal(false)}
                  className="flex-1 bg-gray-300 dark:bg-gray-600 hover:bg-gray-400 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-200 font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-blue-700 hover:bg-blue-800 text-white font-medium py-2 px-4 rounded-lg transition-colors duration-200"
                >
                  Make Payment
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default LendingBorrowing
