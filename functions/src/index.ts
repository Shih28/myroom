// Cloud Functions entry point — exports every callable + trigger.
//
// Phase 0: lifecycle triggers (provisionUser, deleteUserData).
// Phase 1: storageCascade onDelete triggers (notes/recaps/achievements).
// Phase 2 adds the 7 AI callables + the remaining triggers (AI_proxy.md §1).
import "./lib/admin";

export { provisionUser } from "./triggers/provisionUser";
export { deleteUserData } from "./triggers/deleteUserData";
export {
  storageCascadeNote,
  storageCascadeRecap,
  storageCascadeAchievement,
} from "./triggers/storageCascade";
