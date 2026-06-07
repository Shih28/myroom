// Cloud Functions entry point — exports every callable + trigger.
//
// Phase 0: lifecycle triggers only (provisionUser, deleteUserData).
// Phase 2 adds the 7 AI callables + the remaining triggers (AI_proxy.md §1).
import "./lib/admin";

export { provisionUser } from "./triggers/provisionUser";
export { deleteUserData } from "./triggers/deleteUserData";
