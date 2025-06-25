import { Title } from "@solidjs/meta";
import { HttpStatusCode } from "@solidjs/start";

export default function NotFound() {
  return (
    <main class="page-main">
      <Title>404 - Lost in the CAD/CAM</Title>
      <HttpStatusCode code={404} />
      <div class="page-icon-large">
        🔧
      </div>
      <h1 class="page-title">
        404 - Page Not Found
      </h1>
      <p class="page-description">
        Looks like this page got lost in the machining process! The requested
        resource couldn't be located in our CAD/CAM system.
      </p>
      <div class="button-container">
        <a href="/" class="button-primary">
          🏠 Back to Home
        </a>
      </div>
    </main>
  );
}
