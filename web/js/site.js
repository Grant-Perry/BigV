(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  // MARK: - Nav

  const nav = $(".nav");
  const toggle = $(".nav-toggle");
  if (toggle && nav) {
    toggle.addEventListener("click", () => {
      const open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", String(open));
    });
    $$(".nav-links a").forEach((link) => {
      link.addEventListener("click", () => nav.classList.remove("is-open"));
    });
  }

  const sections = $$("main [id]");
  const navLinks = $$(".nav-links a[href^='#']");
  const markActive = () => {
    const y = window.scrollY + 120;
    let current = "";
    for (const section of sections) {
      if (section.offsetTop <= y) current = section.id;
    }
    navLinks.forEach((link) => {
      link.classList.toggle("is-active", link.getAttribute("href") === `#${current}`);
    });
  };
  window.addEventListener("scroll", markActive, { passive: true });

  // MARK: - Live cockpit

  const speedEl = $("[data-speed]");
  const hrEl = $("[data-hr]");
  const distEl = $("[data-dist]");
  const elevEl = $("[data-elev]");
  const watchHr = $("[data-watch-hr]");
  const clockEl = $("[data-clock]");

  let speed = 18.4;
  let hr = 142;
  let dist = 12.6;
  let elev = 486;
  let seconds = 48 * 60 + 12;

  const tickCockpit = () => {
    speed = clamp(speed + (Math.random() - 0.46) * 0.8, 11.2, 28.6);
    hr = Math.round(clamp(hr + (Math.random() - 0.48) * 2.2, 118, 168));
    dist += speed / 3600;
    elev += Math.random() > 0.7 ? 1 : 0;
    seconds += 1;

    if (speedEl) speedEl.textContent = speed.toFixed(1);
    if (hrEl) hrEl.textContent = String(hr);
    if (watchHr) watchHr.textContent = String(hr);
    if (distEl) distEl.textContent = dist.toFixed(1);
    if (elevEl) elevEl.textContent = String(Math.round(elev));
    if (clockEl) {
      const m = Math.floor(seconds / 60);
      const s = seconds % 60;
      clockEl.textContent = `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }
  };

  if (speedEl) setInterval(tickCockpit, 1000);

  // MARK: - Rear radar page demo

  const road = $("[data-road]");
  if (road) {
    const wash = $("[data-wash]");
    const empty = $("[data-empty]");
    const nearest = $("[data-nearest]");
    const countEl = $("[data-count]");
    const closingEl = $("[data-closing]");
    const cars = [];
    const carGlyph = `<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M5.1 10.1c.3-1.4 1.5-2.4 3-2.6L9 7.4h6l.9.1c1.5.2 2.7 1.2 3 2.6l.4 1.7h1.1c.6 0 1.1.5 1.1 1.1v2.1c0 .5-.3.9-.7 1v.9c0 .7-.5 1.2-1.2 1.2h-1.2c-.7 0-1.2-.5-1.2-1.2v-.6H8.8v.6c0 .7-.5 1.2-1.2 1.2H6.4c-.7 0-1.2-.5-1.2-1.2v-.9c-.4-.1-.7-.5-.7-1v-2.1c0-.6.5-1.1 1.1-1.1h1zm1.6 5.6a1 1 0 1 0 0-2 1 1 0 0 0 0 2m10.6 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2M7.2 10.4c.2-.8.8-1.3 1.6-1.4h6.4c.8.1 1.4.6 1.6 1.4l.3 1.2H6.9z"/></svg>`;

    const fraction = (meters) => {
      if (meters <= 0) return 0;
      if (meters >= 140) return 1;
      if (meters <= 40) return (meters / 40) * 0.6;
      return 0.6 + ((meters - 40) / 100) * 0.4;
    };

    const feetLabel = (meters) => `${Math.round((meters * 3.28084) / 5) * 5} ft`;

    const yFor = (meters) => {
      const h = road.clientHeight || 360;
      const usable = h - 80;
      return 56 + usable * fraction(meters);
    };

    const tierFor = (car) => (car.meters < 40 || car.close > 8 ? "is-hot" : "is-amber");

    const spawn = (meters = 140) => {
      const el = document.createElement("div");
      el.className = "radar-car is-amber";
      el.innerHTML = `${carGlyph}<span class="radar-car-ft"></span>`;
      road.appendChild(el);
      cars.push({
        el,
        meters,
        close: 4.2 + Math.random() * 6.4,
        speed: 22 + Math.round(Math.random() * 16),
      });
      render();
    };

    const render = () => {
      cars.forEach((car) => {
        const scale = 1.35 - 0.55 * fraction(car.meters);
        car.el.style.top = `${yFor(car.meters)}px`;
        car.el.style.setProperty("--scale", scale.toFixed(3));
        car.el.className = `radar-car ${tierFor(car)}`;
        const label = car.el.querySelector(".radar-car-ft");
        if (label) label.textContent = feetLabel(car.meters);
      });

      const hot = cars.some((car) => tierFor(car) === "is-hot");
      wash?.classList.toggle("is-hot", hot);
      wash?.classList.toggle("is-amber", !hot && cars.length > 0);
      empty?.classList.toggle("is-hidden", cars.length > 0);
      if (countEl) countEl.textContent = String(cars.length);

      const closest = cars.reduce((best, car) => (!best || car.meters < best.meters ? car : best), null);
      if (nearest) nearest.textContent = closest ? feetLabel(closest.meters) : "—";
      if (closingEl) closingEl.textContent = closest ? `${closest.speed} MPH` : "—";
    };

    const step = () => {
      for (const car of cars) car.meters -= car.close;
      for (let i = cars.length - 1; i >= 0; i -= 1) {
        if (cars[i].meters < 2) {
          cars[i].el.remove();
          cars.splice(i, 1);
        }
      }
      render();
    };

    $("[data-send-car]")?.addEventListener("click", () => spawn());
    $("[data-clear-cars]")?.addEventListener("click", () => {
      cars.splice(0).forEach((car) => car.el.remove());
      render();
    });

    spawn(108);
    spawn(62);
    setInterval(step, 420);
  }

  // MARK: - Pin radar demo to the stem phone

  const radarCard = $("#radar .story-card");
  const radarPhone = $("[data-radar-phone]");
  const pinRadarPhone = () => {
    if (!radarCard || !radarPhone) return;
    const box = radarCard.getBoundingClientRect();
    const imgW = 3168;
    const imgH = 1344;
    const scale = Math.max(box.width / imgW, box.height / imgH);
    const drawW = imgW * scale;
    const drawH = imgH * scale;
    const originX = (box.width - drawW) / 2;
    const originY = (box.height - drawH) / 2;
    const left = 0.376;
    const top = 0.490;
    const width = 0.098;
    const height = 0.478;
    radarPhone.style.left = `${originX + left * drawW}px`;
    radarPhone.style.top = `${originY + top * drawH}px`;
    radarPhone.style.width = `${width * drawW}px`;
    radarPhone.style.height = `${height * drawH}px`;
  };
  pinRadarPhone();
  window.addEventListener("resize", pinRadarPhone, { passive: true });
  if (radarCard && "ResizeObserver" in window) {
    new ResizeObserver(pinRadarPhone).observe(radarCard);
  }

  // MARK: - Climb draw

  const path = $("[data-climb]");
  if (path && "IntersectionObserver" in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) path.classList.add("is-drawn");
      });
    }, { threshold: 0.4 });
    io.observe(path);
  }

  function clamp(n, min, max) {
    return Math.min(max, Math.max(min, n));
  }
})();
