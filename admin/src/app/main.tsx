import React from "react";
import ReactDOM from "react-dom/client";
import { Router } from "@/app/router";
import { QueryClientProvider } from "./providers/query-client";
import { ThemeProvider } from "./providers/theme-provider";
import "./globals.css";

const rootElement = document.getElementById("root");

if (!rootElement) {
  throw new Error("Root element not found");
}

ReactDOM.createRoot(rootElement).render(
  <React.StrictMode>
    <QueryClientProvider>
      <ThemeProvider>
        <Router />
      </ThemeProvider>
    </QueryClientProvider>
  </React.StrictMode>
);
