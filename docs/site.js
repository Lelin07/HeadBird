(function () {
  var THEME_KEY = "headbird-theme";
  var root = document.documentElement;
  var themeToggle = document.getElementById("themeToggle");
  var themeIcon = document.getElementById("themeIcon");
  var releaseLabel = document.getElementById("releaseLabel");
  var releaseLink = document.getElementById("releaseLink");

  function setTheme(theme) {
    root.setAttribute("data-theme", theme);
    var isDark = theme === "dark";
    if (themeIcon) {
      themeIcon.textContent = isDark ? "☀" : "☾";
    }
    if (themeToggle) {
      themeToggle.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode");
    }
  }

  function getInitialTheme() {
    var stored = localStorage.getItem(THEME_KEY);
    if (stored === "dark" || stored === "light") {
      return stored;
    }
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  if (themeToggle) {
    setTheme(getInitialTheme());
    themeToggle.addEventListener("click", function () {
      var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      setTheme(next);
      localStorage.setItem(THEME_KEY, next);
    });
  }

  function showReleaseState(message, isPreRelease) {
    if (!releaseLabel) {
      return;
    }
    releaseLabel.textContent = message;
    releaseLabel.classList.toggle("pre-release", !!isPreRelease);
  }

  fetch("https://api.github.com/repos/Lelin07/HeadBird/releases?per_page=5", {
    headers: {
      Accept: "application/vnd.github+json"
    }
  })
    .then(function (response) {
      if (!response.ok) {
        throw new Error("Failed to fetch releases");
      }
      return response.json();
    })
    .then(function (releases) {
      if (!Array.isArray(releases)) {
        throw new Error("Unexpected response");
      }

      var release = releases.find(function (entry) {
        return !entry.draft;
      });

      if (!release) {
        showReleaseState("Pre-release build: version is still in development.", true);
        return;
      }

      var tag = release.tag_name || "unknown version";
      var published = release.published_at
        ? new Date(release.published_at).toLocaleDateString(undefined, {
            year: "numeric",
            month: "short",
            day: "numeric"
          })
        : "";
      var prefix = release.prerelease ? "Pre-release" : "Latest release";
      var dateSuffix = published ? " (" + published + ")" : "";
      showReleaseState(prefix + ": " + tag + dateSuffix, release.prerelease);

      if (releaseLink && release.html_url) {
        releaseLink.href = release.html_url;
      }
    })
    .catch(function () {
      showReleaseState("Pre-release build: release info unavailable right now.", true);
    });
})();
