﻿namespace MPipeline
{
    [System.Serializable]
    public abstract class PipelineEvent
    {
        public bool enabled = false;
        public bool preEnable { get; private set; }
        public bool postEnable { get; private set; }
        public RenderPipeline.CameraRenderingPath renderingPath { get; private set; }
        public void GetDomainName()
        {
            var dnAttribute = GetType().GetCustomAttributes(
                typeof(PipelineEventAttribute), true
            );
            if (dnAttribute != null && dnAttribute.Length > 0)
            {
                PipelineEventAttribute pt = dnAttribute[0] as PipelineEventAttribute;
                preEnable = pt.preRender;
                postEnable = pt.postRender;
                return;
            }
            preEnable = false;
            postEnable = false;
        }
        public void InitEvent(PipelineResources resources, RenderPipeline.CameraRenderingPath renderingPath)
        {
            this.renderingPath = renderingPath;
            GetDomainName();
            Init(resources);
        }
        public void DisposeEvent()
        {
            Dispose();
        }
        public abstract void Init(PipelineResources resources);
        public abstract void Dispose();
        public abstract bool CheckProperty();
        public virtual void FrameUpdate(PipelineCamera cam, ref PipelineCommandData data) { }
        public virtual void PreRenderFrame(PipelineCamera cam, ref PipelineCommandData data) { }

    }
}