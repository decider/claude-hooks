// Example React component to demonstrate hook functionality

import React, { useState } from 'react';

function UserDashboard({ userId }) {
    const [userData, setUserData] = useState(null);
    const [loading, setLoading] = useState(false);
    
    const fetchUserData = async () => {
        setLoading(true);
        try {
            const response = await fetch(`/api/users/${userId}`);
            const data = await response.json();
            setUserData(data);
        } catch (error) {
            console.error('Failed to fetch user data:', error);
        } finally {
            setLoading(false);
        }
    };
    
    return (
        <div className="dashboard">
            <h1>User Dashboard</h1>
            {loading && <p>Loading...</p>}
            {userData && <pre>{JSON.stringify(userData, null, 2)}</pre>}
            <button onClick={fetchUserData}>Load User Data</button>
        </div>
    );
}

export default UserDashboard;