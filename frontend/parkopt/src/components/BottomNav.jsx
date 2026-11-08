const NAV_ITEMS = [
  { id: 'home', icon: 'home', label: 'Home' },
  { id: 'explore', icon: 'travel_explore', label: 'Explore' },
  { id: 'scan', icon: 'qr_code_2', label: 'Scan' },
  { id: 'bookings', icon: 'calendar_month', label: 'Bookings' },
  { id: 'profile', icon: 'person', label: 'Profile' },
]

export default function BottomNav({ activePage, onNavigate }) {
  return (
    <nav className="parkopt-nav-shell" aria-label="Primary navigation">
      <div className="parkopt-nav">
        {NAV_ITEMS.map((item) => {
          const isActive = activePage === item.id
          const isScan = item.id === 'scan'

          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onNavigate(item.id)}
              aria-label={item.label}
              aria-current={isActive ? 'page' : undefined}
              className={`parkopt-nav__button ${isScan ? 'parkopt-nav__button--scan' : ''}`}
            >
              <span className={`material-symbols-outlined parkopt-nav__icon ${isActive ? 'is-active' : ''}`}>
                {item.icon}
              </span>
            </button>
          )
        })}
      </div>
    </nav>
  )
}
