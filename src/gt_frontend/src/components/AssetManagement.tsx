import React, { useState } from "react";

interface AssetManagementProps {
  actors: any;
  principal: string;
}

const AssetManagement: React.FC<AssetManagementProps> = ({ actors, principal }) => {
  const [form, setForm] = useState({
    ipfs_cid: "",
    rwa_type: "",
    submission_id: "",
    attestation_ids: "",
    verification_hash: "",
  });
  const [status, setStatus] = useState<string | null>(null);
  const [tokenId, setTokenId] = useState<string | null>(null);
  const [tokenData, setTokenData] = useState<any>(null);
  const [certVisible, setCertVisible] = useState(false);
  const [certData, setCertData] = useState<any>(null);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleMint = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus(null);
    setTokenId(null);
    setTokenData(null);
    setCertData(null);
    try {
      const metadata = {
        ipfs_cid: form.ipfs_cid,
        rwa_type: form.rwa_type,
        submission_id: form.submission_id,
        attestation_ids: form.attestation_ids.split(",").map((s) => s.trim()),
        verification_hash: form.verification_hash,
        lien_active: false,
        collateralized: false,
        frozen: false,
      };
      const res = await actors.rwaNft.mintRwaNft(principal, metadata);
      if ("ok" in res) {
        setTokenId(res.ok.toString());
        setStatus("NFT minted!");
      } else {
        setStatus("Mint failed.");
      }
    } catch {
      setStatus("Mint failed.");
    }
  };

  const fetchToken = async () => {
    if (!tokenId) return;
    const owner = await actors.rwaNft.icrc7_owner_of(Number(tokenId));
    const meta = await actors.rwaNft.icrc7_token_metadata(Number(tokenId));
    setTokenData({ owner, meta });
  };

  const fetchCert = async () => {
    if (!tokenId) return;
    const cert = await actors.rwaNft.getCertifiedMetadata(Number(tokenId));
    setCertData(cert);
    setCertVisible(true);
  };

  return (
    <div className="container nft-section">
      <div className="card">
        <h2>NFT Management</h2>
        <form onSubmit={handleMint}>
          <input className="input" name="ipfs_cid" placeholder="IPFS CID" value={form.ipfs_cid} onChange={handleChange} />
          <input className="input" name="rwa_type" placeholder="RWA Type" value={form.rwa_type} onChange={handleChange} />
          <input className="input" name="submission_id" placeholder="Submission ID" value={form.submission_id} onChange={handleChange} />
          <input className="input" name="attestation_ids" placeholder="Attestation IDs (comma-separated)" value={form.attestation_ids} onChange={handleChange} />
          <input className="input" name="verification_hash" placeholder="Verification Hash" value={form.verification_hash} onChange={handleChange} />
          <button className="btn btn-primary" type="submit">Mint NFT</button>
        </form>
        {status && <span className={`badge ${status.includes("fail") ? "badge-error" : "badge-success"}`}>{status}</span>}
      </div>
      <div className="card">
        <h2>Fetch NFT by Token ID</h2>
        <input className="input" placeholder="Token ID" value={tokenId || ""} onChange={(e) => setTokenId(e.target.value)} />
        <div className="flex gap-2">
          <button className="btn btn-secondary" onClick={fetchToken}>Fetch</button>
          <button className="btn btn-outline" onClick={fetchCert}>View Certificate</button>
        </div>
        {tokenData && (
          <div className="card">
            <div><span className="badge">Owner</span> {tokenData.owner.ok}</div>
            <div><span className="badge">Metadata</span> {JSON.stringify(tokenData.meta.ok)}</div>
          </div>
        )}
        {certVisible && certData && (
          <div className="modal" onClick={() => setCertVisible(false)}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()}>
              <h3>Certified Metadata</h3>
              <pre>{JSON.stringify(certData, null, 2)}</pre>
              <button className="btn btn-outline" onClick={() => setCertVisible(false)}>Close</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default AssetManagement;