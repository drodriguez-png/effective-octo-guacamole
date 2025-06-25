import { Title } from "@solidjs/meta";
import Counter from "~/components/Counter";
import "~/styles/PageLayout.css";

export default function Home() {
  return (
    <main class="page-main">
      <Title>CAD/CAM Interface System</Title>
      <div class="page-icon">🏭</div>
      <h1 class="page-title">CAD/CAM Interface System</h1>
      <p class="page-description">
        Welcome to the SAP-Sigmanest interface system. Choose a module below to
        get started.
      </p>
      <div class="button-container">
        <a href="/cds" class="button-primary">
          📦 Code Delivery
        </a>
        <a href="/part_ops" class="button-primary">
          ⚙️ Part Operations
        </a>
        <a href="/renamed_demand" class="button-primary">
          🔄 Renamed Demand
        </a>
        <a href="/boomi" class="button-primary">
          🔗 Boomi
        </a>
      </div>
    </main>
  );
}
