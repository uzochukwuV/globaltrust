import React, { useState } from "react";

interface PropertyVerificationProps {
  actors: any;
  principal: string;
}

const PropertyVerification: React.FC<PropertyVerificationProps> = ({ actors, principal }) => {
  const [form, setForm] = useState({
    document_title: "",
    document_text: "",
    ipfs_hash: "",
    file_type: "",
    file_size: "",
    submission_notes: "",
  });
  const [status, setStatus] = useState<string | null>(null);
  const [result, setResult] = useState<any>(null);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      setForm((prev) => ({
        ...prev,
        file_type: file.type,
        file_size: file.size.toString(),
      }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus(null);
    setResult(null);
    try {
      const res = await actors.rwaVerifier.submitPropertyDocument(
        form.document_title,
        form.document_text,
        form.ipfs_hash || undefined,
        form.file_type || undefined,
        form.file_size ? Number(form.file_size) : undefined,
        form.submission_notes || undefined
      );
      setResult(res);
      setStatus("Submitted!");
    } catch {
      setStatus("Submission failed.");
    }
  };

  return (
    <div className="container verification-section">
      <div className="card">
        <h2>RWA Verification</h2>
        <form onSubmit={handleSubmit}>
          <input className="input" name="document_title" placeholder="Document Title" value={form.document_title} onChange={handleChange} />
          <div
            className="dropzone"
            onDragOver={(e) => e.preventDefault()}
            onDrop={handleDrop}
            style={{ marginBottom: "1rem" }}
          >
            Drag & drop file here (optional)
          </div>
          <textarea className="textarea" name="document_text" placeholder="Document Text" value={form.document_text} onChange={handleChange} />
          <input className="input" name="ipfs_hash" placeholder="IPFS Hash (optional)" value={form.ipfs_hash} onChange={handleChange} />
          <input className="input" name="file_type" placeholder="File Type (optional)" value={form.file_type} onChange={handleChange} />
          <input className="input" name="file_size" type="number" placeholder="File Size (optional)" value={form.file_size} onChange={handleChange} />
          <input className="input" name="submission_notes" placeholder="Notes (optional)" value={form.submission_notes} onChange={handleChange} />
          <button className="btn btn-primary" type="submit">
            Submit
          </button>
        </form>
        {status && <span className={`badge ${status.includes("fail") ? "badge-error" : "badge-success"}`}>{status}</span>}
        {result && (
          <div className="verification-result">
            <span className={`badge badge-${result.verdict === "valid" ? "success" : result.verdict === "suspicious" ? "warning" : "error"}`}>
              {result.verdict?.toUpperCase()}
            </span>
            <span className="confidence-badge">Confidence: {result.confidence_score}</span>
          </div>
        )}
      </div>
    </div>
  );
};

export default PropertyVerification;