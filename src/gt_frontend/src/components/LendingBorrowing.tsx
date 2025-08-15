import React from "react";

interface LendingProps {
  actors: any;
  principal: string;
}

const LendingBorrowing: React.FC<LendingProps> = ({ actors, principal }) => {
  // Mocked loans
  const loans = [
    { id: "L1", amount: 50, status: "repaid", next_due: "-" },
    { id: "L2", amount: 120, status: "active", next_due: "2025-09-10" },
    { id: "L3", amount: 80, status: "pending", next_due: "-" },
  ];

  return (
    <div className="container lending-section">
      <div className="card">
        <h2>Lending & Borrowing</h2>
        <table className="table">
          <thead>
            <tr>
              <th>Loan ID</th>
              <th>Amount</th>
              <th>Status</th>
              <th>Next Due</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {loans.map((l) => (
              <tr key={l.id}>
                <td>{l.id}</td>
                <td>${l.amount}k</td>
                <td>
                  <span className={`badge badge-${l.status === "active" ? "success" : l.status === "pending" ? "warning" : "info"}`}>{l.status}</span>
                </td>
                <td>{l.next_due}</td>
                <td>
                  <button className="btn btn-outline btn-sm">Details</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default LendingBorrowing;