<!-- (C) 2022 - ntop.org     -->
<template>
    <div @submit.prevent="preventEnter" class="modal fade" ref="modal_id" tabindex="-1" role="dialog"
        aria-labelledby="dt-add-filter-modal-title" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered " :class="modal_size" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">
                        <slot name="title"></slot>
                    </h5>
                    <div class="modal-close ms-auto">
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
                        </button>
                    </div>
                </div>
                <div class="modal-body">
                    <slot name="body"></slot>
                </div>
                <div class="modal-footer">
                    <div class="mr-auto">
                    </div>
                    <slot name="footer"></slot>
                    <div class="alert alert-info test-feedback w-100" style="display: none;">
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { defineComponent } from 'vue';
export default defineComponent({
    components: {
    },
    props: {
        id: String,
        size: Number, /* Number from 0 to 3, the higher the larger */
    },
    emits: ["hidden", "showed", "closeModal", "openModal"],
    /** This method is the first method of the component called, it's called before html template creation. */
    created() {
    },
    data() {
        return {
            modal_size: "modal-lg"
            //i18n: (t) => i18n(t),
        };
    },
    /** This method is the first method called after html template creation. */
    mounted() {
        if (this.$props["size"]) {
            const tmp_size = this.$props["size"];
            if (tmp_size === 0) {
                this.modal_size = "modal-sm"
            } else if (tmp_size === 1) {
                this.modal_size = ""
            } else if (tmp_size === 2) {
                this.modal_size = "modal-lg"
            } else if (tmp_size === 3) {
                this.modal_size = "modal-xl"
            } else {
                this.modal_size = "modal-lg"
            }
        } else {
            this.modal_size = "modal-lg"
        }
        let me = this;
        $(this.$refs["modal_id"]).on('shown.bs.modal', function (e) {
            me.$emit("showed");
        });
        $(this.$refs["modal_id"]).on('hidden.bs.modal', function (e) {
            me.$emit("hidden");
        });
        // notifies that component is ready
        ntopng_sync.ready(this.$props["id"]);
    },
    methods: {
        show: function () {
            $(this.$refs["modal_id"]).modal("show");
            // emit openmodal to disable the autorefresh on vs page.
            this.$emit("openModal");
        },
        preventEnter: function () { },
        close: function () {
            $(this.$refs["modal_id"]).modal("hide");
            // emit closemodal to enable (eventually if autorefresh variable is true)
            // the autorefresh on vs page.
            this.$emit("closeModal");
        },
    },
});
</script>
