import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_ENDPOINT = "YOUR_API_ENDPOINT"; // Replace after terraform apply
const CLOUDFRONT_URL = "YOUR_CLOUDFRONT_URL"; // Replace after terraform apply

export default function App() {
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [jobId, setJobId] = useState(null);
  const [status, setStatus] = useState('idle');
  const [outputs, setOutputs] = useState(null);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    if (!jobId || status === 'COMPLETE' || status === 'ERROR') return;

    const interval = setInterval(async () => {
      try {
        const { data } = await axios.get(`${API_ENDPOINT}/status/${jobId}`);
        setStatus(data.status);
        if (data.status === 'COMPLETE') {
          setOutputs(data.outputs);
          setProgress(100);
        } else if (data.status === 'PROCESSING') {
          setProgress(prev => Math.min(prev + 5, 90));
        }
      } catch (err) {
        console.error('Polling error:', err);
      }
    }, 5000);

    return () => clearInterval(interval);
  }, [jobId, status]);

  const handleUpload = async () => {
    if (!file) return;
    setUploading(true);
    setProgress(10);
    
    try {
      const { data } = await axios.get(`${API_ENDPOINT}/upload-url?filename=${file.name}`);
      await axios.put(data.uploadUrl, file, { 
        headers: { 'Content-Type': 'video/mp4' },
        onUploadProgress: (e) => setProgress(10 + (e.loaded / e.total) * 30)
      });
      
      const filename = file.name.split('.')[0];
      setJobId(filename);
      setStatus('PROCESSING');
      setProgress(50);
      setUploading(false);
    } catch (err) {
      alert('Upload failed: ' + err.message);
      setUploading(false);
      setProgress(0);
    }
  };

  return (
    <div className="app">
      <div className="stars"></div>
      <div className="stars2"></div>
      <div className="stars3"></div>
      
      <header className="header">
        <div className="logo-container">
          <div className="logo-icon">🎬</div>
          <div>
            <h1 className="logo-text">MediaFactory</h1>
            <p className="logo-subtitle">Serverless Video Pipeline</p>
          </div>
        </div>
        <div className="status-badge">
          <span className="status-dot"></span>
          Production Ready
        </div>
      </header>

      <main className="main">
        <div className="upload-card">
          <div className="card-header">
            <h2>Upload Video</h2>
            <p>Transform your content into multiple formats</p>
          </div>
          
          <div className="upload-zone" onClick={() => document.getElementById('file-input').click()}>
            <input 
              id="file-input"
              type="file" 
              accept="video/mp4" 
              onChange={(e) => setFile(e.target.files[0])}
              style={{ display: 'none' }}
            />
            <div className="upload-icon">📁</div>
            <p className="upload-text">{file ? file.name : 'Click to select video'}</p>
            <p className="upload-hint">MP4 format • Max 5GB</p>
          </div>

          <button 
            className="upload-btn" 
            onClick={handleUpload} 
            disabled={!file || uploading}
          >
            {uploading ? (
              <>
                <span className="spinner"></span>
                Uploading...
              </>
            ) : (
              <>
                <span>🚀</span>
                Start Processing
              </>
            )}
          </button>
        </div>

        {status === 'PROCESSING' && (
          <div className="processing-card">
            <div className="processing-header">
              <div className="pulse-icon">⚡</div>
              <div>
                <h3>Processing Video</h3>
                <p>AWS MediaConvert is working its magic...</p>
              </div>
            </div>
            
            <div className="progress-container">
              <div className="progress-bar" style={{ width: `${progress}%` }}></div>
            </div>
            <p className="progress-text">{progress}% Complete</p>

            <div className="processing-steps">
              <div className={`step ${progress > 20 ? 'active' : ''}`}>
                <span className="step-icon">📤</span>
                <span>Uploading</span>
              </div>
              <div className={`step ${progress > 50 ? 'active' : ''}`}>
                <span className="step-icon">🎞️</span>
                <span>Transcoding</span>
              </div>
              <div className={`step ${progress > 90 ? 'active' : ''}`}>
                <span className="step-icon">✅</span>
                <span>Finalizing</span>
              </div>
            </div>
          </div>
        )}

        {status === 'COMPLETE' && outputs && (
          <div className="results-card">
            <div className="success-header">
              <div className="success-icon">🎉</div>
              <h2>Transcoding Complete!</h2>
              <p>Your videos are ready for download</p>
            </div>

            <div className="outputs-grid">
              {Object.entries(outputs).map(([key, url]) => (
                <div key={key} className="output-item">
                  <div className="output-info">
                    <span className="output-badge">{key}</span>
                    <span className="output-format">MP4 • Ready</span>
                  </div>
                  <div className="output-actions">
                    <button 
                      className="btn-secondary"
                      onClick={() => window.open(url, '_blank')}
                    >
                      <span>👁️</span>
                      Preview
                    </button>
                    <button 
                      className="btn-primary"
                      onClick={() => navigator.clipboard.writeText(url)}
                    >
                      <span>📋</span>
                      Copy URL
                    </button>
                  </div>
                </div>
              ))}
            </div>

            <button 
              className="reset-btn"
              onClick={() => {
                setFile(null);
                setJobId(null);
                setStatus('idle');
                setOutputs(null);
                setProgress(0);
              }}
            >
              Process Another Video
            </button>
          </div>
        )}
      </main>

      <footer className="footer">
        <p>Powered by AWS Lambda • MediaConvert • S3 • CloudFront</p>
      </footer>
    </div>
  );
}
