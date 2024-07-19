/* @refresh reload */

import { render } from "solid-js/web";
import { A, Navigate, Route, Router } from "@solidjs/router";
import "solid-devtools";

import "./index.css";
import { BatchAssign } from "./BatchAssign";
import { BatchListing } from "./BatchListing";
import { NotFound } from "./NotFound";
import { Feedback } from "./Feedback";

const root = document.getElementById("root");

if (import.meta.env.DEV && !(root instanceof HTMLElement)) {
  throw new Error(
    "Root element not found. Did you forget to add it to your index.html? Or maybe the id attribute got misspelled?",
  );
}

const Layout = (props: any) => {
  return (
    <>
      <nav class="flex items-center justify-between space-x-2 bg-gray-800 p-4">
        <div class="flex items-center space-x-2">
          <A class="router-link" activeClass="ring" href="/assign">
            Machine Console
          </A>
          <A class="router-link" activeClass="ring" href="/batches">
            Batches
          </A>
          <A class="router-link" activeClass="ring" href="/feedback">
            Sigmanest Feedback
          </A>
        </div>
      </nav>
      <main class="m-4 flex h-4/5 grow flex-col place-items-center justify-around">
        {props.children}
      </main>
      <footer class="flex shrink-0 select-none justify-between bg-gray-800 px-2 py-1 font-semibold tracking-wide">
        <p class="text-white">
          &copy; {new Date().getFullYear()} by High Steel Structures LLC
        </p>
        <p class="place-self-center text-xs text-white/50">
          made with <span class="text-red-500">&hearts;</span> by Patrick Miller
        </p>
      </footer>
    </>
  );
};

render(
  () => (
    <Router root={Layout}>
      <Route path="/" component={() => <Navigate href="/assign" />} />
      <Route path="/assign" component={BatchAssign} />
      <Route path="/batches" component={BatchListing} />
      <Route path="/feedback" component={Feedback} />
      <Route path="*404" component={NotFound} />
    </Router>
  ),
  root!,
);
