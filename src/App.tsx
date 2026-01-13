import React from 'react';
import LandingPage from './pages/LandingPage';
import PremiumDashboard from './components/dashboard/PremiumDashboard';

function App() {
  // Show landing page by default, can switch to dashboard via URL or state
  const isDashboard = window.location.hash === '#dashboard';
  
  return isDashboard ? <PremiumDashboard /> : <LandingPage />;
}

export default App;
