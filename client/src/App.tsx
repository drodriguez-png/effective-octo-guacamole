import { type Component, createSignal, For } from "solid-js";

import BatchAssign from "./BatchAssign";
import { Dynamic } from "solid-js/web";

const apps = [
    { name: "Batch Assign",         component: BatchAssign },
    { name: "Batch Listing",        component: () => <p>Not implemented</p> },
    { name: "Sigmanest director",   component: () => <p>Not implemented</p> },
]
const [currentApp, setCurrentApp] = createSignal(0);

const App: Component = () => {
  return (
    <>
      <header class="bg-gray-800 p-4 flex items-center space-x-2 justify-between items-center">
        <div class="flex items-center space-x-2">
          <For each={apps}>{(app, i) =>
            <button
                class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded-full"
                classList={{ "text-black": i() === currentApp() }}
                onClick={() => setCurrentApp(i)}
            >
                {app.name}
            </button>
            }</For>
        </div>
      </header>
      <div class="min-h-screen bg-gray-100 flex flex-col items-center justify-center space-y-4">
        <Dynamic component={apps[currentApp()].component} />
      </div>
    </>
  );
};

export default App;
