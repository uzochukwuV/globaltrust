import React from "react";

interface DashboardProps {
  actors: any;
  principal: string;
}

const Dashboard: React.FC<DashboardProps> = ({ actors, principal }) => {
  // Mocked stats for now
  const stats = [
    { label: "Verified Credentials", value: 4 },
    { label: "Submissions", value: 9 },
    { label: "NFTs", value: 2 },
    { label: "Proposals", value: 3 },
  ];
  const recent = [
    { icon: "📝", text: "Submitted RWA verification", time: "1m ago" },
    { icon: "✅", text: "Attestation issued", time: "2m ago" },
    { icon: "🎨", text: "NFT minted", time: "5m ago" },
    { icon: "🗳️", text: "Voted on DAO proposal", time: "10m ago" },
    { icon: "🔗", text: "Linked DID", time: "1h ago" },
  ];

  return (
    <div className="container dashboard-grid">
      <div className="stats-row">
        {stats.map((s) => (
          <div className="card stat-card" key={s.label}>
            <div className="stat-value">{s.value}</div>
            <div className="stat-label">{s.label}</div>
          </div>
        ))}
      </div>
      <div className="card recent-card">
        <div className="recent-title">Recent Activity</div>
        <ul className="recent-list">
          {recent.map((r, i) => (
            <li className="recent-item" key={i}>
              <span className="badge">{r.icon}</span>
              <span className="recent-text">{r.text}</span>
              <span className="recent-time">{r.time}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default Dashboard;