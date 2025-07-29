 "use client";
import { identity as IdentityVerifier } from "../../../declarations/identity";
import { useState, useEffect } from "react";
import { Identity } from "../../../declarations/identity/identity.did";

    const IdentityManagement = ({ actors, principal }:any) => {
      const [identity, setIdentity] = useState<Identity | null>(null);
      const [credentials, setCredentials] = useState<any>([]);
      const [loading, setLoading] = useState(true);
      const [error, setError] = useState<string| null>();
      const [showAddCredential, setShowAddCredential] = useState(false);

      const [credentialForm, setCredentialForm] = useState({
        credentialType: "",
        issuer: "",
        issuedAt: "",
        expirationDate: "",
        credentialHash: "",
      });

      useEffect(() => {
        loadIdentityData();
      }, [actors]);

      const loadIdentityData = async () => {
        try {
          setLoading(true);
          setError(null);

          const [identityData, credentialsData] = await Promise.all([
            IdentityVerifier.getIdentity?.(principal),
            IdentityVerifier.getVerifiableCredentials?.(principal),
          ]);

          setIdentity(identityData?.[0]!);
          setCredentials(credentialsData || []);
        } catch (err) {
          console.error("Failed to load identity data:", err);
          setError("Failed to load identity data");
        } finally {
          setLoading(false);
        }
      };

      const registerIdentity = async () => {
        try {
          setError(null);
          const result = await IdentityVerifier.registerIdentity();

          if ("ok" in result) {
            setIdentity(result.ok);
          } else {
            setError("Failed to register identity: " + Object.keys(result.err)[0]);
          }
        } catch (err) {
          console.error("Failed to register identity:", err);
          setError("Failed to register identity");
        }
      };

      const addCredential = async (e: any) => {
        e.preventDefault();
        try {
          setError(null);

          const result = await IdentityVerifier.addVerifiableCredential(
            credentialForm.credentialType,
            credentialForm.issuer,
            BigInt(new Date(credentialForm.issuedAt).getTime() * 1000000),
            credentialForm.expirationDate ? [BigInt(new Date(credentialForm.expirationDate).getTime() * 1000000)] : [],
            credentialForm.credentialHash,
          );

          if ("ok" in result) {
            setCredentials([...credentials, {
              id: result.ok.id,
              type: result.ok.credentialType,
              issuer: result.ok.issuer,
              issuedAt: result.ok.issuedAt,
              expirationDate: result.ok.expirationDate,
              credentialHash: result.ok.credentialHash,
            }]);
            setCredentialForm({
              credentialType: "",
              issuer: "",
              issuedAt: "",
              expirationDate: "",
              credentialHash: "",
            });
            setShowAddCredential(false);
          } else {
            setError("Failed to add credential: " + Object.keys(result.err)[0]);
          }
        } catch (err) {
          console.error("Failed to add credential:", err);
          setError("Failed to add credential");
        }
      };

      const handleInputChange = (e:any) => {
        const { name, value } = e.target;
        setCredentialForm((prev) => ({
          ...prev,
          [name]: value,
        }));
      };

      if (loading) {
        return (
          <div className="container">
            <div className="loading">
              <div className="loading-bar"></div>
              <div className="loading-content">
                <div className="loading-card"></div>
                <div className="loading-card large"></div>
              </div>
            </div>
          </div>
        );
      }

      return (
        <div className="container">
          <header className="header">
            <h1>Identity Management</h1>
            <p>Securely manage your self-sovereign identity and verifiable credentials</p>
          </header>

          {error && (
            <div className="error-message">
              <p>{error}</p>
            </div>
          )}

          <section className="card identity-status">
            <div className="card-header">
              <h2>Identity Status</h2>
              {identity && (
                <span className={`status-badge ${identity.verified ? "verified" : "unverified"}`}>
                  {identity.verified ? "Verified" : "Unverified"}
                </span>
              )}
            </div>
            {identity ? (
              <div className="identity-grid">
                <div>
                  <p className="label">Principal ID</p>
                  <p className="value">{identity.id.toString()}</p>
                </div>
                <div>
                  <p className="label">Created At</p>
                  <p className="value">{new Date(Number(identity.createdAt) / 1000000).toLocaleString()}</p>
                </div>
                <div>
                  <p className="label">Last Updated</p>
                  <p className="value">{new Date(Number(identity.updatedAt) / 1000000).toLocaleString()}</p>
                </div>
                <div>
                  <p className="label">Credentials</p>
                  <p className="value">{credentials.length} credential{credentials.length !== 1 ? "s" : ""}</p>
                </div>
              </div>
            ) : (
              <div className="no-identity">
                <p>No identity found. Create your self-sovereign identity to get started.</p>
                <button onClick={registerIdentity} className="primary-button">
                  Create Identity
                </button>
              </div>
            )}
          </section>

          {identity && (
            <section className="card credentials">
              <div className="card-header">
                <h2>Verifiable Credentials</h2>
                <button onClick={() => setShowAddCredential(true)} className="secondary-button">
                  Add Credential
                </button>
              </div>
              <div className="credentials-list">
                {credentials.length > 0 ? (
                  credentials.map((credential: any, index: number) => (
                    <div key={index} className="credential-item">
                      <div className="credential-header">
                        <h3>{credential.credentialType}</h3>
                        <span className={`status-badge ${credential.status.toLowerCase()}`}>
                          {credential.status}
                        </span>
                      </div>
                      <div className="credential-grid">
                        <div>
                          <p className="label">Issuer</p>
                          <p className="value">{credential.issuer}</p>
                        </div>
                        <div>
                          <p className="label">Issued At</p>
                          <p className="value">{new Date(Number(credential.issuedAt) / 1000000).toLocaleDateString()}</p>
                        </div>
                        <div>
                          <p className="label">Credential Hash</p>
                          <p className="value">{credential.credentialHash}</p>
                        </div>
                        {credential.expirationDate && credential.expirationDate.length > 0 && (
                          <div>
                            <p className="label">Expires At</p>
                            <p className="value">{new Date(Number(credential.expirationDate[0]) / 1000000).toLocaleDateString()}</p>
                          </div>
                        )}
                      </div>
                    </div>
                  ))
                ) : (
                  <p className="no-credentials">
                    No credentials added yet. Add your first credential to get started.
                  </p>
                )}
              </div>
            </section>
          )}

          {showAddCredential && (
            <div className="modal">
              <div className="modal-content">
                <div className="modal-header">
                  <h3>Add Verifiable Credential</h3>
                </div>
                <form onSubmit={addCredential} className="modal-form">
                  <div className="form-group">
                    <label>Credential Type</label>
                    <select
                      name="credentialType"
                      value={credentialForm.credentialType}
                      onChange={handleInputChange}
                      required
                    >
                      <option value="">Select type</option>
                      <option value="Passport">Passport</option>
                      <option value="GovernmentID">Government ID</option>
                      <option value="PropertyDeed">Property Deed</option>
                      <option value="AcademicCredential">Academic Credential</option>
                      <option value="ProfessionalLicense">Professional License</option>
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Issuer</label>
                    <input
                      type="text"
                      name="issuer"
                      value={credentialForm.issuer}
                      onChange={handleInputChange}
                      required
                      placeholder="e.g., Government of Country"
                    />
                  </div>
                  <div className="form-group">
                    <label>Issued Date</label>
                    <input
                      type="date"
                      name="issuedAt"
                      value={credentialForm.issuedAt}
                      onChange={handleInputChange}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label>Expiration Date (Optional)</label>
                    <input
                      type="date"
                      name="expirationDate"
                      value={credentialForm.expirationDate}
                      onChange={handleInputChange}
                    />
                  </div>
                  <div className="form-group">
                    <label>Document Hash (IPFS CID)</label>
                    <input
                      type="text"
                      name="credentialHash"
                      value={credentialForm.credentialHash}
                      onChange={handleInputChange}
                      required
                      placeholder="QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                    />
                  </div>
                  <div className="form-actions">
                    <button type="button" onClick={() => setShowAddCredential(false)} className="cancel-button">
                      Cancel
                    </button>
                    <button type="submit" className="secondary-button">
                      Add Credential
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
      );
    };

    export default IdentityManagement;