export type Nest = {
  archivePacketId: number;
  program: Program;
  parts: Part[];
  sheet: Sheet;
  remnants: Remnant[];
};

export type Part = {
  partName: string;
  partQty: number;
  job: string;
  shipment: number;
  nestedArea: number;
  trueArea: number;
};

export type Program = {
  programName: string;
  repeatId: number;
  machineName: string;
  cuttingTime: number;
};

export type Sheet = {
  materialMaster: string;
  sheetName: string;
};

export type Remnant = {
  remnantName: string;
  length: number;
  width: number;
  area: number;
};
