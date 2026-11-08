import { useState, useEffect, useRef, useCallback } from 'react'
import jsQR from 'jsqr'
import './App.css'
import { supabase, supabaseConfigured } from './lib/supabase'

import AuthScreen from './screens/AuthScreen'
import SearchScreen from './screens/SearchScreen'
import FacilityScreen from './screens/FacilityScreen'
import BookingScreen from './screens/BookingScreen'
import PassScreen from './screens/PassScreen'
import MyBookingsScreen from './screens/MyBookingsScreen'
import ProfileScreen from './screens/ProfileScreen'
import BottomNav from './components/BottomNav'

// ── Preserved homepage (blast animation, navy BG, phone mockup) ─────────────

function BlastParticles() {
  return <div className="blast-particles" id="particleCanvasStage" aria-hidden="true" />
}

function Home({ setPage }) {
  const [blasted, setBlasted] = useState(false)

  const spawnBurst = (event, returning = false) => {
    const stage = document.getElementById('particleCanvasStage')
    if (!stage) return
    const rect = event.currentTarget.getBoundingClientRect()
    const originX = event.clientX || rect.left + rect.width / 2
    const originY = event.clientY || rect.top + rect.height / 2
    const count = returning ? 20 : 42
    const colors = ['#C6F36A', '#FFFFFF', '#67E8F9', '#818CF8', '#A7F3D0']
    for (let index = 0; index < count; index += 1) {
      const particle = document.createElement('i')
      const angle = returning
        ? Math.random() * Math.PI * 2
        : (Math.PI * 2 * index) / count + (Math.random() - 0.5) * 0.45
      const distance = returning ? 120 + Math.random() * 80 : 85 + Math.random() * 240
      particle.className = 'spark-particle'
      particle.style.left = `${returning ? originX + Math.cos(angle) * distance : originX}px`
      particle.style.top = `${returning ? originY + Math.sin(angle) * distance : originY}px`
      particle.style.setProperty('--tx', `${returning ? -Math.cos(angle) * distance : Math.cos(angle) * distance}px`)
      particle.style.setProperty('--ty', `${returning ? -Math.sin(angle) * distance : Math.sin(angle) * distance}px`)
      const color = returning ? '#C6F36A' : colors[Math.floor(Math.random() * colors.length)]
      particle.style.width = `${returning ? 4 : Math.floor(Math.random() * 6) + 3}px`
      particle.style.height = particle.style.width
      particle.style.backgroundColor = color
      particle.style.boxShadow = `0 0 12px ${color}`
      stage.appendChild(particle)
      window.setTimeout(() => particle.remove(), returning ? 700 : 900)
    }
  }

  const toggleBlast = (event) => {
    setBlasted((value) => {
      const next = !value
      const wave = document.createElement('div')
      wave.className = 'shockwave-ring'
      wave.style.left = `${event.clientX}px`
      wave.style.top = `${event.clientY}px`
      document.getElementById('particleCanvasStage')?.appendChild(wave)
      window.setTimeout(() => wave.remove(), 950)
      spawnBurst(event, value)
      return next
    })
  }

  const tiltPhone = (event) => {
    const phone = event.currentTarget.querySelector('.phone')
    if (!phone) return
    const rect = event.currentTarget.getBoundingClientRect()
    const deltaX = (event.clientX - rect.left - rect.width / 2) / (rect.width / 2)
    const deltaY = (event.clientY - rect.top - rect.height / 2) / (rect.height / 2)
    phone.style.transform = `perspective(1200px) rotateX(${-deltaY * 12}deg) rotateY(${deltaX * 14}deg) rotateZ(8deg) scale3d(1.02, 1.02, 1.02)`
  }

  return (
    <main className={'home page-shell ' + (blasted ? 'is-blasted' : '')}>
      <BlastParticles />
      <div className="home-copy">
        <button
          className="headline-trigger headline-stage"
          onClick={toggleBlast}
          aria-label={blasted ? 'Reconstruct headline' : 'Blast headline'}
        >
          <span className="blast-word blast-word-1 word-silence">Silence</span>{' '}
          <span className="blast-word blast-word-1 word-your">Your</span>
          <br />
          <span className="blast-word blast-word-2 word-parking">Parking</span>
          <span className="hero-asterisk">✱</span>
          <br />
          <span className="blast-word blast-word-3 word-chaos">Chaos</span>
        </button>

        <div className="headline-actions">
          <button className={'headline-pill' + (blasted ? '' : ' active')} onClick={toggleBlast}>
            Click to blast headline
          </button>
          <button className={'headline-pill' + (blasted ? ' active' : '')} onClick={toggleBlast}>
            Click again to restore
          </button>
        </div>

        <div className="network-banner">
          <div className="network-left">
            <span className="dot" /> ParkOpt.com — Live Network
          </div>
          <button className="network-button" onClick={() => setPage('explore')}>
            Cockpit →
          </button>
        </div>

        <p>
          Arrive without hesitation when spaces are held before departure. Silence the circling,
          bypass ticket gates with auto-lift telemetry, and park with ParkOpt — your frictionless
          urban bay concierge.
        </p>

        <div className="hero-actions">
          <button className="primary magnetic" onClick={() => setPage('explore')}>
            Reserve a Spot
          </button>
          <button className="icon-button" aria-label="Scroll down">
            ⌄
          </button>
          <button className="icon-button" aria-label="More actions">
            ⇣
          </button>
        </div>

        <small className="fineprint">* Zero credit card required for 15 min hold</small>
      </div>

      <div
        className="home-visual device-float-stage"
        onMouseMove={tiltPhone}
        onMouseLeave={(event) => {
          const phone = event.currentTarget.querySelector('.phone')
          if (phone) phone.style.transform = ''
        }}
      >
        <div className={'monument-backdrop ' + (blasted ? 'monument-visible' : '')}>PARKOPT</div>
        <div className="status-pill status-pill-top">
          <span className="status-dot" /> Auto-Gate Armed <strong>99.5%</strong>
        </div>
        <div className="status-pill status-pill-right">
          <span className="status-dot" /> Stall reserved <strong>Bay L2-04</strong>
        </div>

        <div className="phone device-tilt">
          <div className="phone-scan" />
          <div className="phone-notch" />
          <div className="phone-header">
            <span>02:59</span>
            <span className="signal">● ● ▰</span>
          </div>

          <div className="phone-copy">
            <small>Hey, Alex!</small>
            <strong>Welcome to Isham Deck</strong>
          </div>

          <h2>
            Ready for
            <br />
            another seamless
            <br />
            arrival?
          </h2>

          <div className="phone-pills">
            <span>Recent</span>
            <span>EV Rapid</span>
            <span>Covered</span>
          </div>

          <div className="phone-card primary-card">
            <small>Active Bay Hold</small>
            <strong>Isham Multilevel · L2-04</strong>
            <span className="lime">● Live Beacon</span>
            <small>14:29 hold remaining</small>
          </div>

          <div className="phone-card secondary-card">
            <strong>Memorial Garage</strong>
            <span>$2.50/hr</span>
          </div>
        </div>
      </div>
    </main>
  )
}

// ── Old desktop header (home page only) ─────────────────────────────────────
function HomeHeader({ onExplore }) {
  return (
    <header className="topbar-home">
      <div className="topbar-inner">
        <div className="eyebrow home-eyebrow">
          <span className="pulse" /> TEAM INNOVERSE
        </div>
        <button className="mini-brand" onClick={onExplore}>
          ParkOpt
        </button>
      </div>
    </header>
  )
}

// ── Root app ─────────────────────────────────────────────────────────────────
const PROTECTED_PAGES = ['bookings', 'profile']

function parseQrCode(value) {
  const trimmed = String(value ?? '').trim()

  if (!trimmed) return null

  const lower = trimmed.toLowerCase()
  const facilityMatch = trimmed.match(/(?:facility|facility_id|location)[\s:_-]*([a-z0-9-]+)/i)
  const spaceMatch = trimmed.match(/(?:space|bay|slot)[\s:_-]*([a-z0-9-]+)/i)

  if (facilityMatch) {
    return { type: 'facility', id: facilityMatch[1] }
  }

  if (spaceMatch) {
    return { type: 'space', id: spaceMatch[1] }
  }

  if (/(facility|space|location|parkopt|bay)/i.test(lower)) {
    return { type: 'generic', id: trimmed }
  }

  return { type: 'generic', id: trimmed }
}

export default function App() {
  const [page, setPage] = useState('home')
  const [session, setSession] = useState(null)
  const [authLoading, setAuthLoading] = useState(true)
  const [authRedirect, setAuthRedirect] = useState(null)

  // Drill-down state
  const [selectedFacility, setSelectedFacility] = useState(null)
  const [searchParams, setSearchParams] = useState(null)
  const [confirmedBooking, setConfirmedBooking] = useState(null)
  const [scanOpen, setScanOpen] = useState(false)
  const [scanPreviousPage, setScanPreviousPage] = useState('explore')
  const [scanStatus, setScanStatus] = useState('Align the QR code within the frame')
  const [scanError, setScanError] = useState('')
  const [flashEnabled, setFlashEnabled] = useState(false)
  const [flashSupported, setFlashSupported] = useState(false)
  const [manualCode, setManualCode] = useState('')
  const [scanResult, setScanResult] = useState('')
  const videoRef = useRef(null)
  const streamRef = useRef(null)
  const detectionFrameRef = useRef(null)
  const fileInputRef = useRef(null)
  const scanHandledRef = useRef(false)
  const lastScannedValueRef = useRef('')

  const stopCamera = useCallback(() => {
    if (detectionFrameRef.current) {
      cancelAnimationFrame(detectionFrameRef.current)
      detectionFrameRef.current = null
    }

    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop())
      streamRef.current = null
    }

    if (videoRef.current) {
      videoRef.current.pause()
      videoRef.current.srcObject = null
    }
  }, [])

  const handleDecodedQr = useCallback(
    (value) => {
      const cleaned = String(value ?? '').trim()

      if (!cleaned) {
        setScanError('No QR value was detected. Try again or use manual entry.')
        return
      }

      if (lastScannedValueRef.current === cleaned) {
        return
      }

      lastScannedValueRef.current = cleaned
      setScanResult(cleaned)

      const parsed = parseQrCode(cleaned)
      const label = parsed ? `${parsed.type.toUpperCase()} ${parsed.id}` : cleaned
      setScanStatus(`Scanned: ${label}`)

      setTimeout(() => {
        setScanOpen(false)
        setManualCode('')
        setScanError('')
        setScanResult('')
        setPage(scanPreviousPage)
      }, 250)
    },
    [scanPreviousPage]
  )

  const detectQrFromImage = useCallback((imageElement) => {
    const canvas = document.createElement('canvas')
    const width = imageElement.naturalWidth || imageElement.width || 640
    const height = imageElement.naturalHeight || imageElement.height || 480
    canvas.width = width
    canvas.height = height

    const ctx = canvas.getContext('2d', { willReadFrequently: true })
    if (!ctx) {
      setScanError('Image decoding is not supported in this browser.')
      return
    }

    ctx.drawImage(imageElement, 0, 0, width, height)
    const imageData = ctx.getImageData(0, 0, width, height)
    const result = jsQR(imageData.data, width, height, { inversionAttempts: 'dontInvert' })

    if (!result) {
      setScanError('No QR code was found in that image. Try a clearer photo or use manual entry.')
      return
    }

    handleDecodedQr(result.data)
  }, [handleDecodedQr])

  const startCamera = useCallback(async () => {
    stopCamera()
    setScanError('')
    setScanStatus('Requesting camera access...')
    setFlashEnabled(false)
    setFlashSupported(false)
    scanHandledRef.current = false

    if (!window.isSecureContext && !['localhost', '127.0.0.1'].includes(window.location.hostname)) {
      setScanError('Camera access requires HTTPS. Open the app over a secure connection to scan QR codes.')
      return
    }

    if (!navigator.mediaDevices?.getUserMedia) {
      setScanError('This browser does not support camera access.')
      return
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false,
      })

      streamRef.current = stream

      if (videoRef.current) {
        videoRef.current.srcObject = stream
        await videoRef.current.play().catch(() => undefined)
      }

      const track = stream.getVideoTracks()[0]
      const capabilities = track?.getCapabilities?.() || {}
      setFlashSupported(Boolean(capabilities.torch))

      const detectLoop = () => {
        const video = videoRef.current

        if (!video || video.readyState < 2) {
          detectionFrameRef.current = requestAnimationFrame(detectLoop)
          return
        }

        if (scanHandledRef.current) return

        const canvas = document.createElement('canvas')
        const width = video.videoWidth || 640
        const height = video.videoHeight || 480
        canvas.width = width
        canvas.height = height

        const context = canvas.getContext('2d', { willReadFrequently: true })

        if (!context) {
          setScanError('The camera stream could not be decoded in this browser.')
          return
        }

        context.drawImage(video, 0, 0, width, height)
        const imageData = context.getImageData(0, 0, width, height)
        const result = jsQR(imageData.data, width, height, { inversionAttempts: 'dontInvert' })

        if (result) {
          scanHandledRef.current = true
          handleDecodedQr(result.data)
          return
        }

        detectionFrameRef.current = requestAnimationFrame(detectLoop)
      }

      detectionFrameRef.current = requestAnimationFrame(detectLoop)
      setScanStatus('Align the QR code within the frame')
    } catch (error) {
      if (error && error.name === 'NotAllowedError') {
        setScanError('Camera permission was denied. Please allow camera access to scan a QR code.')
      } else if (error && error.name === 'NotFoundError') {
        setScanError('No camera is available on this device right now.')
      } else {
        setScanError('The camera could not be opened. Please try again or use a gallery image instead.')
      }
    }
  }, [handleDecodedQr, stopCamera])

  useEffect(() => {
    if (!scanOpen) {
      stopCamera()
      return undefined
    }

    void startCamera()

    return () => {
      stopCamera()
    }
  }, [scanOpen, startCamera, stopCamera])

  // Auth state listener
  useEffect(() => {
    if (!supabaseConfigured) {
      setAuthLoading(false)
      return
    }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setAuthLoading(false)
    })
    const { data: listener } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession)
    })
    return () => listener.subscription.unsubscribe()
  }, [])

  // Intercept nav to protected pages → bounce to auth
  const navigate = (dest) => {
    if (dest === 'scan') {
      setScanPreviousPage(page)
      setScanOpen(true)
      return
    }

    setScanOpen(false)
    lastScannedValueRef.current = ''
    setScanResult('')
    setScanError('')
    setScanStatus('Align the QR code within the frame')

    if (PROTECTED_PAGES.includes(dest) && !session) {
      setPage('auth')
      return
    }
    if (dest !== 'auth') {
      setAuthRedirect(null)
    }
    // Reset drill-down when navigating away
    if (!['facility', 'booking', 'pass'].includes(dest)) {
      setSelectedFacility(null)
      setSearchParams(null)
      setConfirmedBooking(null)
    }
    setPage(dest)
  }

  const handleAuth = (_user, sess) => {
    setSession(sess)

    if (authRedirect && authRedirect.type === 'booking') {
      setSelectedFacility(authRedirect.facility)
      setSearchParams(authRedirect.params)
      setAuthRedirect(null)
      setPage('booking')
      return
    }

    setAuthRedirect(null)
    setPage('explore')
  }

  const handleSelectFacility = (facility, params) => {
    setSelectedFacility(facility)
    setSearchParams(params)
    setPage('facility')
  }

  const handleBook = (facility, params) => {
    if (!session) {
      setSelectedFacility(facility)
      setSearchParams(params)
      setAuthRedirect({ type: 'booking', facility, params })
      setPage('auth')
      return
    }

    setSelectedFacility(facility)
    setSearchParams(params)
    setPage('booking')
  }

  const handleConfirmed = (bookingResult) => {
    setConfirmedBooking(bookingResult)
    setPage('pass')
  }

  const handleSignOut = () => {
    setSession(null)
    stopCamera()
    setScanOpen(false)
    setScanError('')
    setScanStatus('Align the QR code within the frame')
    setScanResult('')
    lastScannedValueRef.current = ''
    setPage('home')
  }

  // While checking auth, show minimal spinner
  if (authLoading) {
    return (
      <div className="min-h-screen bg-[#051424] flex items-center justify-center">
        <span className="w-8 h-8 border-2 border-[#c5f269]/30 border-t-[#c5f269] rounded-full animate-spin" />
      </div>
    )
  }

  const handleManualScan = (event) => {
    event.preventDefault()

    const trimmed = manualCode.trim()
    if (!trimmed) {
      setScanError('Enter a QR or location code to continue.')
      return
    }

    setScanError('')
    const parsed = parseQrCode(trimmed)
    setScanStatus(parsed ? `Scanned: ${parsed.type.toUpperCase()} ${parsed.id}` : `Scanned: ${trimmed}`)
    setScanResult(trimmed)
    setTimeout(() => {
      setScanOpen(false)
      setPage(scanPreviousPage)
      setManualCode('')
      setScanStatus('Align the QR code within the frame')
    }, 250)
  }

  const toggleTorch = async () => {
    const track = streamRef.current?.getVideoTracks()[0]
    const capabilities = track?.getCapabilities?.() || {}

    if (!track || !capabilities.torch) {
      setFlashSupported(false)
      return
    }

    try {
      const nextState = !flashEnabled
      await track.applyConstraints({
        advanced: [{ torch: nextState }],
      })
      setFlashEnabled(nextState)
    } catch (error) {
      setScanError('This device could not switch the flashlight on or off.')
    }
  }

  const handleGalleryFile = async (event) => {
    const file = event.target.files?.[0]
    if (!file) return

    const imageUrl = URL.createObjectURL(file)
    const image = new Image()
    image.onload = () => {
      detectQrFromImage(image)
      URL.revokeObjectURL(imageUrl)
      event.target.value = ''
    }
    image.onerror = () => {
      setScanError('The selected image could not be opened.')
      URL.revokeObjectURL(imageUrl)
      event.target.value = ''
    }
    image.src = imageUrl
  }

  // ── Render ────────────────────────────────────────────────────────────────
  const showBottomNav = !['home', 'auth', 'pass', 'facility', 'booking'].includes(page) && !scanOpen
  const activeNavPage = scanOpen ? 'scan' : page

  return (
    <>
      {/* Home page keeps its original desktop header */}
      {page === 'home' && <HomeHeader onExplore={() => navigate('explore')} />}

      {/* Page content */}
      {page === 'home' && <Home setPage={navigate} />}

      {page === 'auth' && <AuthScreen onAuth={handleAuth} />}

      {!scanOpen && page === 'explore' && (
        <SearchScreen
          session={session}
          onSelectFacility={handleSelectFacility}
        />
      )}

      {page === 'facility' && selectedFacility && (
        <FacilityScreen
          facility={selectedFacility}
          searchParams={searchParams}
          onBook={handleBook}
          onBack={() => setPage('explore')}
        />
      )}

      {page === 'booking' && selectedFacility && (
        <BookingScreen
          facility={selectedFacility}
          searchParams={searchParams}
          session={session}
          onConfirmed={handleConfirmed}
          onBack={() => setPage('facility')}
        />
      )}

      {page === 'pass' && confirmedBooking && (
        <PassScreen
          booking={confirmedBooking}
          onViewBookings={() => navigate('bookings')}
          onGoHome={() => navigate('home')}
        />
      )}

      {page === 'bookings' && (
        <MyBookingsScreen session={session} />
      )}

      {page === 'profile' && (
        <ProfileScreen session={session} onSignOut={handleSignOut} />
      )}

      {/* Auth gate message for un-authed direct nav */}
      {['bookings', 'profile'].includes(page) && !session && (
        <div className="fixed inset-0 flex flex-col items-center justify-center bg-surface gap-4">
          <span className="material-symbols-outlined text-[48px] text-text-muted">lock</span>
          <p className="text-[16px] text-text-muted">Sign in to access this page</p>
          <button
            onClick={() => setPage('auth')}
            className="px-6 py-3 rounded-full bg-[#c5f269] text-on-primary font-bold text-[14px]"
            style={{ fontFamily: 'Space Grotesk, sans-serif' }}
          >
            Sign In
          </button>
        </div>
      )}

      {/* Bottom navigation (all app pages except home, auth, pass) */}
      {showBottomNav && (
        <BottomNav
          activePage={activeNavPage}
          onNavigate={navigate}
        />
      )}

      {scanOpen && (
        <div className="parkopt-scan-overlay" role="dialog" aria-modal="true" aria-label="QR scanner">
          <div className="parkopt-scan-topbar">
            <button
              type="button"
              className="parkopt-scan-back"
              onClick={() => {
                stopCamera()
                setScanOpen(false)
                setPage(scanPreviousPage)
                setManualCode('')
                setScanError('')
                setScanStatus('Align the QR code within the frame')
                setScanResult('')
                lastScannedValueRef.current = ''
              }}
              aria-label="Back to previous screen"
            >
              <span className="material-symbols-outlined">arrow_back</span>
            </button>
            <div className="parkopt-scan-title">Scan QR Code</div>
          </div>

          <div className="parkopt-scan-view">
            {navigator.mediaDevices?.getUserMedia ? (
              <video ref={videoRef} className="parkopt-scan-video" autoPlay muted playsInline />
            ) : (
              <div className="parkopt-scan-placeholder">Camera unavailable on this device.</div>
            )}

            <div className="parkopt-scan-frame" aria-hidden="true">
              <div className="parkopt-scan-target" />
            </div>
            <div className="parkopt-scan-line" aria-hidden="true" />
            <div className="parkopt-scan-overlay-noise" aria-hidden="true" />
          </div>

          <div className="parkopt-scan-status">
            <div className="parkopt-scan-status-text">
              {scanError || scanStatus || 'Align the QR code within the frame'}
            </div>
            {scanResult ? <div className="parkopt-scan-result">Last code: {scanResult}</div> : null}
          </div>

          <div className="parkopt-scan-controls">
            <button
              type="button"
              className="parkopt-scan-control"
              disabled={!flashSupported}
              onClick={toggleTorch}
            >
              <span className="material-symbols-outlined">{flashEnabled ? 'flashlight_off' : 'flashlight_on'}</span>
              {flashSupported ? (flashEnabled ? 'Flash on' : 'Flash off') : 'Flash unavailable'}
            </button>

            <button
              type="button"
              className="parkopt-scan-control"
              onClick={() => fileInputRef.current?.click()}
            >
              <span className="material-symbols-outlined">photo_library</span>
              Gallery
            </button>

            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              capture="environment"
              className="parkopt-hidden-input"
              onChange={handleGalleryFile}
            />
          </div>

          <form className="parkopt-manual-entry" onSubmit={handleManualScan}>
            <input
              type="text"
              value={manualCode}
              onChange={(event) => setManualCode(event.target.value)}
              placeholder="Enter QR or location code"
              aria-label="Enter QR or location code"
            />
            <button type="submit">Use code</button>
          </form>
        </div>
      )}
    </>
  )
}
