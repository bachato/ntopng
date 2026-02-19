<!-- (C) 2022 - ntop.org -->
<template>
   <!-- Bootstrap Modal Component - Reusable modal dialog wrapper -->
   <div @submit.prevent="preventEnter" class="modal fade" ref="modalRef" tabindex="-1" role="dialog"
      aria-labelledby="dt-add-filter-modal-title" aria-hidden="true">
      <!-- Modal dialog container with dynamic sizing based on prop -->
      <div class="modal-dialog modal-dialog-centered" :class="modalSizeClass" role="document">
         <div class="modal-content">
            <!-- Modal Header Section -->
            <div class="modal-header">
               <h5 class="modal-title">
                  <slot name="title"></slot> <!-- Title content from parent -->
               </h5>
               <div class="modal-close ms-auto">
                  <!-- Bootstrap's default close button -->
                  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
               </div>
            </div>

            <!-- Modal Body Section - Main content area -->
            <div class="modal-body">
               <slot name="body"></slot> <!-- Body content from parent -->
            </div>

            <!-- Modal Footer Section - Action buttons area -->
            <div class="modal-footer">
               <div class="mr-auto"></div>
               <slot name="footer"></slot> <!-- Footer content from parent -->
               <!-- Hidden feedback area for testing purposes -->
               <div class="alert alert-info test-feedback w-100" style="display: none;"></div>
            </div>
         </div>
      </div>
   </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";

// ----------------------------
// Props - Component Configuration
// ----------------------------
const props = defineProps({
   id: String,      // Optional unique identifier for sync management
   size: {
      type: Number,
      default: 2,     // Default size = modal-lg (Bootstrap's large modal)
      // Size mapping: 0=sm, 1=normal, 2=lg, 3=xl
   },
});

// ----------------------------
// Emits - Events to Parent Components
// ----------------------------
const emit = defineEmits([
   "hidden",        // Emitted when modal is completely hidden (after animation)
   "showed",        // Emitted when modal is fully shown (after animation)
   "closeModal",    // Emitted when close() method is called
   "openModal"      // Emitted when show() method is called
]);

// ----------------------------
// Refs - Template References
// ----------------------------
const modalRef = ref(null);  // Reference to the actual modal DOM element

// ----------------------------
// Computed Properties
// ----------------------------
/**
 * Maps the numeric size prop to Bootstrap's modal size classes
 * @returns {string} Bootstrap modal size class
 * 
 * Size mapping:
 * 0 → "modal-sm"  (Small modal)
 * 1 → ""          (Default/normal size)
 * 2 → "modal-lg"  (Large modal)
 * 3 → "modal-xl"  (Extra large modal)
 * default → "modal-lg" (Fallback to large)
 */
const modalSizeClass = computed(() => {
   switch (props.size) {
      case 0:
         return "modal-sm";
      case 1:
         return "";
      case 2:
         return "modal-lg";
      case 3:
         return "modal-xl";
      default:
         return "modal-lg";
   }
});

// ----------------------------
// Methods - Public API
// ----------------------------

/**
 * Shows the modal using Bootstrap's modal API
 * Emits 'openModal' event to notify parent
 */
const show = () => {
   $(modalRef.value).modal("show");
   emit("openModal"); // Notify parent that modal is opened
};

/**
 * Hides the modal using Bootstrap's modal API
 * Emits 'closeModal' event to notify parent
 */
const close = () => {
   $(modalRef.value).modal("hide");
   emit("closeModal"); // Notify parent that modal is closed
};

/**
 * Prevents form submission when pressing Enter key
 * This is a placeholder function attached to @submit.prevent
 * to ensure forms inside the modal don't accidentally submit
 * and cause page reload
 */
const preventEnter = () => {
   // Empty function - intentionally does nothing
   // Its purpose is only to prevent default form submission behavior
};

// ----------------------------
// Lifecycle Hooks
// ----------------------------

/**
 * Component mounted lifecycle hook
 * Sets up Bootstrap event listeners and notifies sync system
 */
onMounted(() => {
   // Bootstrap modal events - forward them to parent via emits
   $(modalRef.value).on("shown.bs.modal", () => emit("showed"));
   $(modalRef.value).on("hidden.bs.modal", () => emit("hidden"));

   // Notify ntopng synchronization system that component is ready
   // This is part of ntopng's component sync mechanism
   if (props.id) {
      ntopng_sync.ready(props.id);
   }
});

// Expose methods to parent components
// Parent can call these methods via template refs
// Example: <Modal ref="myModal"> then myModal.show()
defineExpose({ show, close });
</script>