import React from "react";

interface HeaderProps {
  principal: string;
  currentView: string;
  setCurrentView: (view: string) => void;
  theme: string;
  toggleTheme: () => void;
  logout: () => void;
}

const Header: React.FC<HeaderProps> = ({
  principal,
  currentView,
  setCurrentView,
  theme,
  toggleTheme,
  logout,
}) => {
  return (
    <header className="header">
      <div className="brand">
        <span className="brand-logo"></span>
        GlobalTrust
      </div>
      <nav className="nav">
        <div className={"nav-item" + (currentView === "dashboard" ? " active" : "")} onClick={() => setCurrentView("dashboard")}>
          Dashboard
        </div>
        <div className={"nav-item" + (currentView === "identity" ? " active" : "")} onClick={() => setCurrentView("identity")}>
          Identity
        </div>
        <div className={"nav-item" + (currentView === "verification" ? " active" : "")} onClick={() => setCurrentView("verification")}>
          Verify
        </div>
        <div className={"nav-item" + (currentView === "nfts" ? " active" : "")} onClick={() => setCurrentView("nfts")}>
          NFTs
        </div>
        <div className={"nav-item" + (currentView === "marketplace" ? " active" : "")} onClick={() => setCurrentView("marketplace")}>
          Marketplace
        </div>
        <div className={"nav-item" + (currentView === "lending" ? " active" : "")} onClick={() => setCurrentView("lending")}>
          Lending
        </div>
      </nav>
      <div className="flex items-center gap-2 px-2">
        <span title={principal}>
          {principal.slice(0, 6)}...{principal.slice(-4)}
        </span>
        <button className="btn btn-ghost" onClick={toggleTheme}>
          {theme === "dark" ? "🌑" : "🌕"}
        </button>
        <button className="btn btn-outline" onClick={logout}>
          Logout
        </button>
      </div>
    </header>
  );
};

export default Header;