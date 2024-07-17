import {
  Component,
  For,
  Match,
  Show,
  Suspense,
  createEffect,
  createSignal,
  onMount,
} from "solid-js";
import { FiInfo, FiX } from "solid-icons/fi";

type Batch = {
  batch: string;
  mm: string;
  type: string;
};

const BatchListing: Component = () => {
  const [batches, setBatches] = createSignal<Batch[]>([]);
  const [batchToShow, setBatchToShow] = createSignal<Batch>();
  const [showInfo, setShowInfo] = createSignal(false);

  createEffect(() => {
    console.log(batches());
  });

  const showBatch = (batch: Batch) => {
    setBatchToShow(batch);
    setShowInfo(true);
  };

  onMount(async () => {
    const response = await fetch(`/api/batches`);
    setBatches(await response.json());
  });

  return (
    <>
      <Suspense
        fallback={
          <p class="col-span-full row-span-full place-self-center">
            Fetching...
          </p>
        }
      >
        <div
          class="overflow-auto m-4 shadow-md sm:rounded-lg"
          style={{ height: "80vh" }}
        >
          <table class="w-full text-sm text-gray-500">
            <thead class="z-10 top-0 sticky text-xs text-gray-700 uppercase bg-gradient-to-tr from-amber-300 to-orange-400">
              <tr>
                <th scope="col" class="px-6 py-3">
                  Batch
                </th>
                <th scope="col" class="px-6 py-3">
                  Material Master
                </th>
                <th scope="col" class="px-6 py-3">
                  Type
                </th>
              </tr>
            </thead>
            <tbody>
              <For each={batches()}>
                {(item) => (
                  <tr
                    class="border-t hover:bg-gray-100 py-4"
                    onClick={() => showBatch(item)}
                  >
                    <th
                      scope="row"
                      class="px-6 py-4 font-medium text-gray-900 whitespace-nowrap"
                    >
                      {item.batch}
                    </th>
                    <td class="px-6 py-4">{item.mm}</td>
                    <td class="px-6 py-4">{item.type}</td>
                  </tr>
                )}
              </For>
            </tbody>
          </table>

          <dialog
            class="border rounded-lg backdrop-blur-sm overflow-auto"
            open={showInfo()}
          >
            <header class="p-2 border-b-2 bg-gradient-to-tr from-amber-300 to-orange-400">
              <p>
                Batch:{" "}
                <span class="select-all underline">{batchToShow()?.batch}</span>
              </p>
              <FiX
                class="absolute top-2 right-2 rounded hover:ring-2"
                onClick={() => setShowInfo(false)}
              />
            </header>
            <main class="p-4">
              <ul>
                <li>
                  Material Master:
                  <span class="select-all underline decoration-sky-500">
                    {batchToShow()?.mm}
                  </span>
                </li>
                <li>Batch Type: {batchToShow()?.type}</li>
              </ul>
            </main>
          </dialog>
        </div>
      </Suspense>
    </>
  );
};

export default BatchListing;
