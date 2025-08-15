import React from "react";

interface MarketplaceProps {
  actors: any;
  principal: string;
}

const Marketplace: React.FC<MarketplaceProps> = ({ actors, principal }) => {
  // Mocked listings
  const listings = [
    { id: "1", title: "House in Berlin", price: 100, status: "active" },
    { id: "2", title: "Office Space NYC", price: 250, status: "pending" },
    { id: "3", title: "Condo Tokyo", price: 180, status: "active" },
  ];

  return (
    <div className="container marketplace-section">
      <div className="card">
        <h2>Marketplace</h2>
        <table className="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Property</th>
              <th>Price</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {listings.map((l) => (
              <tr key={l.id}>
                <td>{l.id}</td>
                <td>{l.title}</td>
                <td>${l.price}k</td>
                <td>
                  <span className={`badge badge-${l.status === "active" ? "success" : "warning"}`}>{l.status}</span>
                </td>
                <td>
                  <button className="btn btn-outline btn-sm">View</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Marketplace;