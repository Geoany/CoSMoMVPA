%% Permutation test example
%
% A simple example of running a permutation test to determine the
% signifance of classification accuracies

%% Set the number of permutations
niter=1000;

%% Define dataset, classifier, partitioner
data_path=cosmo_get_data_path('s01');

data_fn=fullfile(data_path,'glm_T_stats_perrun.nii');
mask_fn=fullfile(data_path,'vt_mask.nii');
ds=cosmo_fmri_dataset(data_fn,'mask',mask_fn,...
                        'targets',repmat(1:6,1,10),...
                        'chunks',floor(((1:60)-1)/6)+1);

% select only a few samples - otherwise we have too much power (!)
keep_targets=[1 2 5 6 ];
nkeep_target=numel(keep_targets)
keep_targets_mask=~prod(bsxfun(@minus,keep_targets,ds.sa.targets)==0,2);
ds_keep=cosmo_dataset_slice_samples(ds,keep_targets_mask);

params_classes_chunk_counts=[7 9 7 9; 8 8 8 8; 9 7 9 7]+1;
nparams=size(params_classes_chunk_counts,1);
for j=1:nparams
    chunk_counts=params_classes_chunk_counts(j,:);
    msk=false(size(ds_keep.sa.targets));
    for k=1:nkeep_target
        msk=msk | keep_targets(k)==ds_keep.sa.targets & ds_keep.sa.chunks <= chunk_counts(k);
    end
    
    ds=cosmo_dataset_slice_samples(ds_keep,msk);

    classifier=@cosmo_classify_naive_bayes;
    partitions=cosmo_splithalf_partitioner(ds);

    %% compute classification accuracy of the original data
    [pred, acc]=cosmo_cross_validate(ds, classifier, partitions);

    %% prepare for permutations
    acc0=zeros(niter,1); % allocate space for permuted accuracies 
    ds0=ds; % make a copy of the dataset

    %% for _niter_ iterations, reshuffle the labels and compute accuracy
    % >>
    for k=1:niter
        ds0.sa.targets=cosmo_randomize_targets(ds);
        [foo, acc0(k)]=cosmo_cross_validate(ds0, classifier, partitions);
    end
    % <<
    
    p=sum(acc<acc0)/niter;
    fprintf('%d permutations: accuracy=%.3f, p=%.4f\n', niter, acc, p);

    subplot(1,nparams,j)
    bins=0:10/niter:1; 
    h=histc(acc0,bins);
    bar(bins,h)
    hold on
    line([acc acc],[0,max(h)])
    hold off
    title(sprintf('[ %s] chunks: acc=%.3f', sprintf('%d ',chunk_counts), acc))
end
