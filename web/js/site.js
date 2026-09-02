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

  // MARK: - Radar playground

  const tape = $("[data-tape]");
  const wash = $("[data-wash]");
  const nearest = $("[data-nearest]");
  const countEl = $("[data-count]");
  if (tape) {
    const cars = [];

    const tierFor = (top) => {
      if (top < 90) return "is-hot";
      if (top < 220) return "is-close";
      return "is-far";
    };

    const spawn = (start = 380) => {
      const el = document.createElement("div");
      const speedMph = (22 + Math.random() * 18).toFixed(0);
      el.className = `car ${tierFor(start)}`;
      el.style.top = `${start}px`;
      el.dataset.speed = `${speedMph} mph`;
      tape.appendChild(el);
      cars.push({ el, top: start, close: 6 + Math.random() * 5 });
      render();
    };

    const render = () => {
      cars.forEach((car) => {
        car.el.style.top = `${car.top}px`;
        car.el.className = `car ${tierFor(car.top)}`;
      });
      const hot = cars.some((car) => car.top < 90);
      wash?.classList.toggle("is-on", hot);
      if (countEl) countEl.textContent = String(cars.length);
      const countWord = $("[data-count-word]");
      if (countWord) countWord.textContent = cars.length === 1 ? "vehicle" : "vehicles";
      const closest = cars.reduce((min, car) => Math.min(min, car.top), 999);
      if (nearest) {
        nearest.textContent = cars.length ? `${Math.max(8, Math.round(closest * 1.1))} ft` : "Clear";
      }
    };

    const step = () => {
      for (const car of cars) car.top -= car.close;
      for (let i = cars.length - 1; i >= 0; i -= 1) {
        if (cars[i].top < 22) {
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

    spawn(310);
    spawn(210);
    setInterval(step, 420);
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
