import React, { useState } from "react";

interface IdentityManagementProps {
  actors: any;
  principal: string;
}

const IdentityManagement: React.FC<IdentityManagementProps> = ({ actors, principal }) => {
  const [status, setStatus] = useState<string | null>(null);
  const [credStatus, setCredStatus] = useState<string | null>(null);
  const [form, setForm] = useState({
    credentialType: "",
    issuer: "",
    issuedAt: "",
    expirationDate: "",
    credentialHash: "",
  });

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleRegister = async () => {
    setStatus(null);
    try {
      await actors.identity.registerIdentity();
      setStatus("Identity registered!");
    } catch {
      setStatus("Registration failed.");
    }
  };

  const handleAddCredential = async (e: React.FormEvent) => {
    e.preventDefault();
    setCredStatus(null);
    try {
      await actors.identity.addVerifiableCredential(
        form.credentialType,
        form.issuer,
        Number(form.issuedAt),
        form.expirationDate ? Number(form.expirationDate) : null,
        form.credentialHash
      );
      setCredStatus("Credential added!");
    } catch {
      setCredStatus("Failed to add credential.");
    }
  };

  return (
    <div className="container identity-section">
      <div className="card">
        <h2>Register Identity</h2>
        <button className="btn btn-primary" onClick={handleRegister}>
          Register
        </button>
        {status && <span className={`badge ${status.includes("failed") ? "badge-error" : "badge-success"}`}>{status}</span>}
      </div>
      <div className="card">
        <h2>Add Verifiable Credential</h2>
        <form onSubmit={handleAddCredential}>
          <input className="input" name="credentialType" placeholder="Credential Type" value={form.credentialType} onChange={handleChange} />
          <input className="input" name="issuer" placeholder="Issuer" value={form.issuer} onChange={handleChange} />
          <input className="input" name="issuedAt" type="number" placeholder="Issued At (timestamp)" value={form.issuedAt} onChange={handleChange} />
          <input className="input" name="expirationDate" type="number" placeholder="Expiration Date (timestamp, optional)" value={form.expirationDate} onChange={handleChange} />
          <input className="input" name="credentialHash" placeholder="Credential Hash" value={form.credentialHash} onChange={handleChange} />
          <button className="btn btn-primary" type="submit">
            Add Credential
          </button>
        </form>
        {credStatus && <span className={`badge ${credStatus.includes("Failed") ? "badge-error" : "badge-success"}`}>{credStatus}</span>}
      </div>
    </div>
  );
};

export default IdentityManagement;