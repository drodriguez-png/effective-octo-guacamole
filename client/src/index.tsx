/* @refresh reload */

import { render } from "solid-js/web";
import { A, Navigate, Route, Router } from "@solidjs/router";

import "./index.css";
import { BatchAssign } from "./BatchAssign";
import { BatchListing } from "./BatchListing";

const root = document.getElementById("root");

if (import.meta.env.DEV && !(root instanceof HTMLElement)) {
  throw new Error(
    "Root element not found. Did you forget to add it to your index.html? Or maybe the id attribute got misspelled?"
  );
}

const Layout = (props: any) => {
  return (
    <>
      <nav class="bg-gray-800 p-4 flex items-center space-x-2 justify-between items-center">
        <div class="flex items-center space-x-2">
          <A
            class="bg-gradient-to-r from-cyan-500 to-blue-500 transition ease-in-out duration-300 hover:from-indigo-500 hover:via-purple-500 hover:to-pink-500 text-white font-bold py-2 px-4 rounded-full ring-white ring-offset-2"
            activeClass="ring"
            href="/assign"
          >
            Batch Assign
          </A>
          <A
            class="bg-gradient-to-r from-cyan-500 to-blue-500 transition ease-in-out duration-300 hover:from-indigo-500 hover:via-purple-500 hover:to-pink-500 text-white font-bold py-2 px-4 rounded-full ring-white ring-offset-2"
            activeClass="ring"
            href="/batches"
          >
            Batch Listing
          </A>
        </div>
      </nav>
      <main class="h-4/5 m-4 flex flex-col grow justify-around place-items-center">
        {props.children}
      </main>
      <footer class="bg-gray-800 px-2 py-1 flex shrink-0 justify-between font-semibold tracking-wide select-none">
        <p class="text-white">
          &copy; {new Date().getFullYear()} by High Steel Structures LLC
        </p>
        <p class="text-white/50 text-xs place-self-center">
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
    </Router>
  ),
  root!
);
